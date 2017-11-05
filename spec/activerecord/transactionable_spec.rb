require "spec_helper"

describe Activerecord::Transactionable do
  it "has a version number" do
    expect(Activerecord::Transactionable::VERSION).not_to be nil
  end

  class FarOutError < StandardError; end

  class PlainVanillaIceCream < ActiveRecord::Base
    attr_accessor :topping
    validates_presence_of :topping
    def raise_something(error)
      raise error
    end
    def self.raise_something(error)
      raise error
    end
    def do_something(*args)
      1
    end
    def self.do_something(*args)
      1
    end
    def do_block(*args, &block)
      result = yield *args if block_given?
      result
    end
    def self.do_block(*args, &block)
      yield *args if block_given?
    end
    def logger
      self.class.logger
    end
    def self.logger
      @logger ||= NullLogger.new
    end
  end

  class TransactionableIceCream < PlainVanillaIceCream
    include Activerecord::Transactionable
    def raise_something(error:, **opts)
      transaction_wrapper(**opts) do
        super(error)
      end
    end
    def do_something(args:, **opts)
      transaction_wrapper(**opts) do
        super(*args)
      end
    end
    def do_block(args:, **opts, &block)
      transaction_wrapper(**opts) do
        super(*args) do |args|
          result = yield
          result
        end
      end
    end
    def self.raise_something(error:, **opts)
      transaction_wrapper(**opts) do
        super(error)
      end
    end
    def self.do_something(args:, **opts)
      transaction_wrapper(**opts) do
        super(*args)
      end
    end
    def self.do_block(args:, **opts, &block)
      transaction_wrapper(**opts) do
        super(*args) do |args|
          yield
        end
      end
    end
    def logger
      self.class.logger
    end
    def self.logger
      @logger ||= NullLogger.new
    end
  end

  let(:record_invalid_error) { ActiveRecord::RecordInvalid.new(PlainVanillaIceCream.new) }

  context "for successful transaction" do
    context "without concern" do
      it("returns method result") {
        expect(PlainVanillaIceCream.new.do_something(2)).to eq(1)
      }
    end
    context "with concern" do
      it("is success") {
        tresult = TransactionableIceCream.new.do_something(args: 2)
        expect(tresult.success?).to eq(true)
      }
    end
  end

  context "for ActiveRecord::Rollback" do
    context "without concern" do
      it("raises") {
        expect {
          PlainVanillaIceCream.new.raise_something(ActiveRecord::Rollback)
        }.to raise_error ActiveRecord::Rollback
      }
    end
    context "with concern" do
      # NOTE: this spec tests default behavior of rails, but it is complicated, and confusing, and worth calling out in a spec.
      it("does not raise because swallowed by ActiveRecord's handling of the transaction") {
        expect {
          TransactionableIceCream.new.raise_something(error: ActiveRecord::Rollback)
        }.to_not raise_error
      }
      it("is success") {
        # Because the error is caught by Rails outside the context of this gem's
        #   inner transaction error handling, *and* not re-raised by Rails
        tresult = TransactionableIceCream.new.raise_something(error: ActiveRecord::Rollback)
        expect(tresult.success?).to eq(true)
      }
    end
  end

  context "for ActiveRecord::RecordInvalid" do
    context "without concern" do
      it("raises") {
        expect {
          PlainVanillaIceCream.new.raise_something(record_invalid_error)
        }.to raise_error ActiveRecord::RecordInvalid
      }
    end
    context "with concern" do
      let(:object) { TransactionableIceCream.new }
      it("does not raise") {
        expect {
          object.raise_something(error: record_invalid_error)
        }.to_not raise_error
      }
      it("is fail") {
        tresult = object.raise_something(error: record_invalid_error)
        expect(tresult.fail?).to be true
      }
      it("adds error to base") {
        object.valid?
        error = ActiveRecord::RecordInvalid.new(object)
        object.raise_something(error: error)
        expect(object.errors.full_messages).to eq ["Topping can't be blank"]
      }
      it("logs error") {
        expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside]")
        TransactionableIceCream.raise_something(error: FarOutError, rescued_errors: FarOutError, object: object)
      }
      context "with lock" do
        it("does not raise") {
          expect {
            object.raise_something(error: record_invalid_error, lock: true)
          }.to_not raise_error
        }
        it("is fail") {
          tresult = object.raise_something(error: record_invalid_error, lock: true)
          expect(tresult.fail?).to be true
        }
        it("adds error to base") {
          object.valid?
          error = ActiveRecord::RecordInvalid.new(object)
          object.raise_something(error: error, lock: true)
          expect(object.errors.full_messages).to eq ["Topping can't be blank"]
        }
        it("logs error") {
          expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside]")
          TransactionableIceCream.raise_something(error: FarOutError, rescued_errors: FarOutError, object: object, lock: true)
        }
      end
    end
  end

  context "for any error that needs handling" do
    context "without concern" do
      it("raises") {
        expect {
          PlainVanillaIceCream.new.raise_something(FarOutError)
        }.to raise_error FarOutError
      }
    end
    context "with concern" do
      context "instance level" do
        it("does not raise") {
          expect {
            TransactionableIceCream.new.raise_something(error: FarOutError, rescued_errors: FarOutError)
          }.to_not raise_error
        }
        it("is fail") {
          tresult = TransactionableIceCream.new.raise_something(error: FarOutError, rescued_errors: FarOutError)
          expect(tresult.fail?).to be true
        }
        it("adds error to base") {
          ice_cream = TransactionableIceCream.new
          ice_cream.raise_something(error: FarOutError, rescued_errors: FarOutError)
          expect(ice_cream.errors.full_messages).to eq ["FarOutError"]
        }
        context "with lock" do
          it("does not raise") {
            expect {
              TransactionableIceCream.new.raise_something(error: FarOutError, lock: true, rescued_errors: FarOutError)
            }.to_not raise_error
          }
          it("is fail") {
            tresult = TransactionableIceCream.new.raise_something(error: FarOutError, lock: true, rescued_errors: FarOutError)
            expect(tresult.fail?).to be true
          }
          it("adds error to base") {
            ice_cream = TransactionableIceCream.new
            ice_cream.raise_something(error: FarOutError, lock: true, rescued_errors: FarOutError)
            expect(ice_cream.errors.full_messages).to eq ["FarOutError"]
          }
        end
      end
      context "class level" do
        context "with object provided" do
          let(:object) { TransactionableIceCream.new }
          it("does not raise") {
            expect {
              TransactionableIceCream.raise_something(error: FarOutError, object: object, rescued_errors: FarOutError)
            }.to_not raise_error
          }
          it("is fail") {
            tresult = TransactionableIceCream.raise_something(error: FarOutError, object: object, rescued_errors: FarOutError)
            expect(tresult.fail?).to be true
          }
          it("adds error to base") {
            TransactionableIceCream.raise_something(error: FarOutError, object: object, rescued_errors: FarOutError)
            expect(object.errors.full_messages).to eq ["FarOutError"]
          }
          it("logs error") {
            expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside]")
            TransactionableIceCream.raise_something(error: FarOutError, object: object, rescued_errors: FarOutError)
          }
          context "with lock" do
            it("does not raise") {
              expect {
                TransactionableIceCream.raise_something(error: FarOutError, object: object, lock: true, rescued_errors: FarOutError)
              }.to_not raise_error
            }
            it("is fail") {
              tresult = TransactionableIceCream.raise_something(error: FarOutError, object: object, lock: true, rescued_errors: FarOutError)
              expect(tresult.fail?).to be true
            }
            it("adds error to base") {
              TransactionableIceCream.raise_something(error: FarOutError, object: object, lock: true, rescued_errors: FarOutError)
              expect(object.errors.full_messages).to eq ["FarOutError"]
            }
            it("logs error") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside]")
              TransactionableIceCream.raise_something(error: FarOutError, object: object, lock: true, rescued_errors: FarOutError)
            }
          end
        end
        context "no object provided" do
          it("does not raise") {
            expect {
              TransactionableIceCream.raise_something(error: FarOutError, object: nil, rescued_errors: FarOutError)
            }.to_not raise_error
          }
          it("is fail") {
            tresult = TransactionableIceCream.raise_something(error: FarOutError, object: nil, rescued_errors: FarOutError)
            expect(tresult.fail?).to be true
          }
          it("logs error") {
            expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FarOutError: FarOutError [inside]")
            TransactionableIceCream.raise_something(error: FarOutError, object: nil, rescued_errors: FarOutError)
          }
          context "with lock" do
            it("raises") {
              expect {
                TransactionableIceCream.raise_something(error: FarOutError, object: nil, lock: true)
              }.to raise_error ArgumentError, "No object to lock!"
            }
            it("does not log error") {
              expect(TransactionableIceCream.logger).to receive(:error).never
              expect {
                TransactionableIceCream.raise_something(error: FarOutError, object: nil, lock: true)
              }.to raise_error ArgumentError
            }
          end
        end
        context "retriable" do
          context "not nested" do
            it("does not raise") {
              expect {
                TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError)
              }.to_not raise_error
            }
            it("is fail") {
              tresult = TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError)
              expect(tresult.fail?).to be true
            }
            it("logs both attempts") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside 1st attempt]").once
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside 2nd attempt]").once
              TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError)
            }
            context "with lock" do
              it("does not raise") {
                expect {
                  TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError, lock: true)
                }.to_not raise_error
              }
              it("is fail") {
                tresult = TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError, lock: true)
                expect(tresult.fail?).to be true
              }
              it("logs both attempts") {
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside 1st attempt]").once
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside 2nd attempt]").once
                TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError, lock: true)
              }
            end
          end
          context "nested" do
            context "inner block" do
              subject {
                TransactionableIceCream.new.do_block(args: [1]) do
                  TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError)
                end
              }
              it("does not raise") {
                expect { subject }.to_not raise_error
              }
              it("is fail") {
                expect(subject.fail?).to be true
              }
              it("logs both attempts") {
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested inside 1st attempt]").once
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested inside 2nd attempt]").once
                subject
              }
              context "with lock" do
                subject {
                  TransactionableIceCream.new.do_block(args: [1]) do
                    TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError, lock: true)
                  end
                }
                it("does not raise") {
                  expect { subject }.to_not raise_error
                }
                it("is fail") { expect(subject.fail?).to be true }
                it("logs both attempts") {
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested inside 1st attempt]").once
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested inside 2nd attempt]").once
                  subject
                }
              end
            end
            context "outer block" do
              subject {
                TransactionableIceCream.new.do_block(args: [1], retriable_errors: FarOutError) do
                  TransactionableIceCream.new.raise_something(error: FarOutError)
                end
              }
              it("does not raise") {
                expect { subject }.to_not raise_error
              }
              it("is fail") {
                expect(subject.fail?).to be true
              }
              context "with lock" do
                subject {
                  TransactionableIceCream.new.do_block(args: [1], retriable_errors: FarOutError, lock: true) do
                    TransactionableIceCream.new.raise_something(error: FarOutError)
                  end
                }
                it("does not raise") {
                  expect { subject }.to_not raise_error
                }
                it("is fail") { expect(subject.fail?).to be true }
                it("logs both attempts") {
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside 1st attempt]").once
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside 2nd attempt]").once
                  subject
                }
              end
            end
          end
        end
        context "outside_retriable" do
          context "not nested" do
            it("does not raise") {
              expect {
                TransactionableIceCream.new.raise_something(error: FarOutError, outside_retriable_errors: FarOutError)
              }.to_not raise_error
            }
            it("returns false") {
              tresult = TransactionableIceCream.new.raise_something(error: FarOutError, outside_retriable_errors: FarOutError)
              expect(tresult.fail?).to be true
            }
            it("logs both attempts") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside 1st attempt]").once
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside 2nd attempt]").once
              TransactionableIceCream.new.raise_something(error: FarOutError, outside_retriable_errors: FarOutError)
            }
            context "with lock" do
              it("does not raise") {
                expect {
                  TransactionableIceCream.new.raise_something(error: FarOutError, outside_retriable_errors: FarOutError, lock: true)
                }.to_not raise_error
              }
              it("is fail") {
                tresult = TransactionableIceCream.new.raise_something(error: FarOutError, outside_retriable_errors: FarOutError, lock: true)
                expect(tresult.fail?).to be true
              }
              it("logs both attempts") {
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside 1st attempt]").once
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside 2nd attempt]").once
                TransactionableIceCream.new.raise_something(error: FarOutError, outside_retriable_errors: FarOutError, lock: true)
              }
            end
          end
          context "nested" do
            context "outer block" do
              subject {
                TransactionableIceCream.new.do_block(args: [1], outside_retriable_errors: FarOutError) do
                  TransactionableIceCream.new.raise_something(error: FarOutError)
                end
              }
              it("does not raise") {
                expect { subject }.to_not raise_error
              }
              it("is fail") {
                expect(subject.fail?).to be true
              }
              context "with lock" do
                subject {
                  TransactionableIceCream.new.do_block(args: [1], outside_retriable_errors: FarOutError, lock: true) do
                    TransactionableIceCream.new.raise_something(error: FarOutError)
                  end
                }
                it("does not raise") {
                  expect { subject }.to_not raise_error
                }
                it("is fail") { expect(subject.fail?).to be true }
                it("logs both attempts") {
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside 1st attempt]").once
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside 2nd attempt]").once
                  subject
                }
              end
            end
            context "inner block" do
              subject {
                TransactionableIceCream.new.do_block(args: [1]) do
                  TransactionableIceCream.new.raise_something(error: FarOutError, outside_retriable_errors: FarOutError)
                end
              }
              it("does not raise") {
                expect { subject }.to_not raise_error
              }
              it("is fail") {
                expect(subject.fail?).to be true
              }
              it("logs both attempts") {
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested outside 1st attempt]").once
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested outside 2nd attempt]").once
                subject
              }
              context "with lock" do
                subject {
                  TransactionableIceCream.new.do_block(args: [1]) do
                    TransactionableIceCream.new.raise_something(error: FarOutError, outside_retriable_errors: FarOutError, lock: true)
                  end
                }
                it("does not raise") {
                  expect { subject }.to_not raise_error
                }
                it("is fail") { expect(subject.fail?).to be true }
                it("logs both attempts") {
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested outside 1st attempt]").once
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested outside 2nd attempt]").once
                  subject
                }
              end
            end
          end
        end
      end
      context "reraisable" do
        it("raises") {
          expect {
            TransactionableIceCream.new.raise_something(error: FarOutError, reraisable_errors: FarOutError)
          }.to raise_error FarOutError
        }
        it("logs error") {
          expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside re-raising!]").once
          expect {
            TransactionableIceCream.new.raise_something(error: FarOutError, reraisable_errors: FarOutError)
          }.to raise_error FarOutError
        }
        context "with lock" do
          it("raises") {
            expect {
              TransactionableIceCream.new.raise_something(error: FarOutError, reraisable_errors: FarOutError, lock: true)
            }.to raise_error FarOutError
          }
          it("logs error") {
            expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside re-raising!]").once
            expect {
              TransactionableIceCream.new.raise_something(error: FarOutError, reraisable_errors: FarOutError, lock: true)
            }.to raise_error FarOutError
          }
        end
      end
      context "outside_reraisable" do
        it("raises") {
          expect {
            TransactionableIceCream.new.raise_something(error: FarOutError, outside_reraisable_errors: FarOutError)
          }.to raise_error FarOutError
        }
        it("logs error") {
          expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside re-raising!]").once
          expect {
            TransactionableIceCream.new.raise_something(error: FarOutError, outside_reraisable_errors: FarOutError)
          }.to raise_error FarOutError
        }
        context "with lock" do
          it("raises") {
            expect {
              TransactionableIceCream.new.raise_something(error: FarOutError, outside_reraisable_errors: FarOutError, lock: true)
            }.to raise_error FarOutError
          }
          it("logs error") {
            expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside re-raising!]").once
            expect {
              TransactionableIceCream.new.raise_something(error: FarOutError, outside_reraisable_errors: FarOutError, lock: true)
            }.to raise_error FarOutError
          }
        end
      end
    end
  end
end
