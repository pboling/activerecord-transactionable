# frozen_string_literal: true

RSpec.describe Activerecord::Transactionable do
  let(:record_invalid_error) { ActiveRecord::RecordInvalid.new(PlainVanillaIceCream.new) }

  it "has a version number" do
    expect(Activerecord::Transactionable::VERSION).not_to be_nil
  end

  class FarOutError < StandardError; end

  class OnRetryError < StandardError; end

  class FirstTimeError < StandardError; end

  class PlainVanillaIceCream < ActiveRecord::Base
    attr_accessor :topping

    validates_presence_of :topping
    def raise_something(error)
      raise error
    end

    def self.raise_something(error)
      raise error
    end

    def do_something(*_args)
      1
    end

    def self.do_something(*_args)
      1
    end

    def do_block(*args)
      result = yield(*args) if block_given?
      result
    end

    def self.do_block(*args)
      yield(*args) if block_given?
    end

    def logger
      self.class.logger
    end

    def self.logger
      @logger ||= NullLogger.new
    end

    def self.log_with(alt_logger)
      old_logger = @logger.dup
      @logger = alt_logger
      yield
      @logger = old_logger
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

    def do_block(args:, **opts)
      transaction_wrapper(**opts) do
        super(*args) do |_args|
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

    def self.do_switch(args:, **opts)
      transaction_wrapper(**opts) do |is_retry|
        if is_retry
          raise OnRetryError, "it is a retry with #{args}"
        else
          raise FirstTimeError, "it is the first time with #{args}"
        end
      end
    end

    def self.do_block(args:, **opts)
      transaction_wrapper(**opts) do
        super(*args) do |_args|
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

      context "with to_h" do
        it("has diagnostic information") {
          tresult = TransactionableIceCream.new.do_something(args: 2)
          expect(tresult.to_h).to eq({result: "success", attempt: 1, type: nil, context: "inside", nested: false})
        }
      end

      context "with to_s" do
        it("has diagnostic information") {
          tresult = TransactionableIceCream.new.do_something(args: 2)
          expect(tresult.to_s).to eq("{:result=>\"success\", :type=>nil, :context=>\"inside\", :nested=>false, :attempt=>1}")
        }
      end

      context "with bad argument" do
        subject(:bad_argument) do
          TransactionableIceCream.new.do_something(args: 2, bad: :argument, really: "quite bad")
        end

        it("raises ArgumentError") {
          block_is_expected.to raise_error(ArgumentError, /does not know how to handle arguments: \[:bad, :really\]/)
        }
      end

      context "with bad rescue inside transaction" do
        subject(:bad_rescue_inside) do
          TransactionableIceCream.new.do_something(
            args: 2,
            rescued_errors: [
              ActiveRecord::StatementInvalid,
              ActiveRecord::RecordNotUnique,
            ],
          )
        end

        it("raises ArgumentError") {
          block_is_expected.to raise_error(
            ArgumentError,
            /should not rescue \[ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid, ActiveRecord::RecordNotUnique\] inside a transaction: \[:rescued_errors, :prepared_errors, :retriable_errors, :reraisable_errors, :num_retry_attempts\]/,
          )
        }
      end

      context "with requires_new" do
        subject(:requires_new) do
          logger = Logger.new($stdout)
          logger.level = Logger::DEBUG
          TransactionableIceCream.log_with(logger) do
            TransactionableIceCream.new.do_something(
              args: 2,
              requires_new: true,
            )
          end
        end

        it "logs nothing when not nested in an open transaction" do
          pending_for(engine: "truffleruby")
          output = capture(:stdout) do
            requires_new
          end
          expect(output).to eq ""
        end

        it "has debug logging" do
          pending_for(engine: "truffleruby")
          output = capture(:stdout) do
            TransactionableIceCream.new.do_block(args: [1]) do
              requires_new
            end
          end
          logs = [
            "Will start a nested transaction.",
          ]
          expect(output).to include(*logs)
        end
      end
    end
  end

  context "for ActiveRecord::Rollback" do
    context "without concern" do
      it("raises") {
        expect do
          PlainVanillaIceCream.new.raise_something(ActiveRecord::Rollback)
        end.to raise_error ActiveRecord::Rollback
      }
    end

    context "with concern" do
      # NOTE: this spec tests default behavior of rails, but it is complicated, and confusing, and worth calling out in a spec.
      it("does not raise because swallowed by ActiveRecord's handling of the transaction") {
        expect do
          TransactionableIceCream.new.raise_something(error: ActiveRecord::Rollback)
        end.not_to raise_error
      }

      it("is success") {
        # Because the error is caught by Rails outside the context of this gem's
        #   inner transaction error handling, *and* not re-raised by Rails
        tresult = TransactionableIceCream.new.raise_something(error: ActiveRecord::Rollback)
        expect(tresult.success?).to eq(true)
      }

      it("has diagnostic information") {
        tresult = TransactionableIceCream.new.raise_something(error: ActiveRecord::Rollback)
        expect(tresult.to_h).to eq({result: "success", attempt: 1, type: nil, context: "outside", nested: false})
      }
    end
  end

  context "for ActiveRecord::RecordInvalid" do
    context "without concern" do
      it("raises") {
        expect do
          PlainVanillaIceCream.new.raise_something(record_invalid_error)
        end.to raise_error ActiveRecord::RecordInvalid
      }
    end

    context "with concern" do
      let(:object) { TransactionableIceCream.new }

      it("does not raise") {
        expect do
          object.raise_something(error: record_invalid_error)
        end.not_to raise_error
      }

      it("is fail") {
        tresult = object.raise_something(error: record_invalid_error)
        expect(tresult.fail?).to be true
      }

      it("has diagnostic information") {
        tresult = object.raise_something(error: record_invalid_error)
        expect(tresult.to_h).to eq({
          attempt: 1,
          result: "fail",
          type: "already_added",
          context: "outside",
          nested: false,
          error: "ActiveRecord::RecordInvalid",
          message: "Validation failed: ",
        })
      }

      it("adds error to base") {
        object.valid?
        error = ActiveRecord::RecordInvalid.new(object)
        object.raise_something(error: error)
        expect(object.errors.full_messages).to eq ["Topping can't be blank"]
      }

      it("logs error") {
        expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside][1]")
        TransactionableIceCream.raise_something(error: FarOutError, rescued_errors: FarOutError, object: object)
      }

      context "with lock" do
        it("does not raise") {
          expect do
            object.raise_something(error: record_invalid_error, lock: true)
          end.not_to raise_error
        }

        it("is fail") {
          tresult = object.raise_something(error: record_invalid_error, lock: true)
          expect(tresult.fail?).to be true
        }

        it("has diagnostic information") {
          tresult = object.raise_something(error: record_invalid_error, lock: true)
          expect(tresult.to_h).to eq({
            attempt: 1,
            result: "fail",
            type: "already_added",
            context: "outside",
            nested: false,
            error: "ActiveRecord::RecordInvalid",
            message: "Validation failed: ",
          })
        }

        it("adds error to base") {
          object.valid?
          error = ActiveRecord::RecordInvalid.new(object)
          object.raise_something(error: error, lock: true)
          expect(object.errors.full_messages).to eq ["Topping can't be blank"]
        }

        it("logs error") {
          expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside][1]")
          TransactionableIceCream.raise_something(
            error: FarOutError,
            rescued_errors: FarOutError,
            object: object,
            lock: true,
          )
        }
      end
    end
  end

  context "for any error that needs handling" do
    context "without concern" do
      it("raises") {
        expect do
          PlainVanillaIceCream.new.raise_something(FarOutError)
        end.to raise_error FarOutError
      }
    end

    context "with concern" do
      context "instance level" do
        it("does not raise") {
          expect do
            TransactionableIceCream.new.raise_something(error: FarOutError, rescued_errors: FarOutError)
          end.not_to raise_error
        }

        it("is fail") {
          tresult = TransactionableIceCream.new.raise_something(error: FarOutError, rescued_errors: FarOutError)
          expect(tresult.fail?).to be true
        }

        it("has diagnostic information") {
          tresult = TransactionableIceCream.new.raise_something(error: FarOutError, rescued_errors: FarOutError)
          expect(tresult.to_h).to eq({
            attempt: 1,
            result: "fail",
            type: "needing_added",
            context: "inside",
            nested: false,
            error: "FarOutError",
            message: "FarOutError",
          })
        }

        it("adds error to base") {
          ice_cream = TransactionableIceCream.new
          ice_cream.raise_something(error: FarOutError, rescued_errors: FarOutError)
          expect(ice_cream.errors.full_messages).to eq ["FarOutError"]
        }

        context "with lock" do
          it("does not raise") {
            expect do
              TransactionableIceCream.new.raise_something(error: FarOutError, lock: true, rescued_errors: FarOutError)
            end.not_to raise_error
          }

          it("is fail") {
            tresult = TransactionableIceCream.new.raise_something(
              error: FarOutError,
              lock: true,
              rescued_errors: FarOutError,
            )
            expect(tresult.fail?).to be true
          }

          it("has diagnostic information") {
            tresult = TransactionableIceCream.new.raise_something(
              error: FarOutError,
              lock: true,
              rescued_errors: FarOutError,
            )
            expect(tresult.to_h).to eq({
              attempt: 1,
              result: "fail",
              type: "needing_added",
              context: "inside",
              nested: false,
              error: "FarOutError",
              message: "FarOutError",
            })
          }

          it("adds error to base") {
            ice_cream = TransactionableIceCream.new
            ice_cream.raise_something(error: FarOutError, lock: true, rescued_errors: FarOutError)
            expect(ice_cream.errors.full_messages).to eq ["FarOutError"]
          }
        end

        context "reraisable" do
          it("raises") {
            expect do
              TransactionableIceCream.new.raise_something(error: FarOutError, reraisable_errors: FarOutError)
            end.to raise_error FarOutError
          }

          it("logs error") {
            expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside re-raising!][1]").once
            expect do
              TransactionableIceCream.new.raise_something(error: FarOutError, reraisable_errors: FarOutError)
            end.to raise_error FarOutError
          }

          context "with lock" do
            it("raises") {
              expect do
                TransactionableIceCream.new.raise_something(
                  error: FarOutError,
                  reraisable_errors: FarOutError,
                  lock: true,
                )
              end.to raise_error FarOutError
            }

            it("logs error") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside re-raising!][1]").once
              expect do
                TransactionableIceCream.new.raise_something(
                  error: FarOutError,
                  reraisable_errors: FarOutError,
                  lock: true,
                )
              end.to raise_error FarOutError
            }
          end
        end

        context "outside_reraisable" do
          it("raises") {
            expect do
              TransactionableIceCream.new.raise_something(error: FarOutError, outside_reraisable_errors: FarOutError)
            end.to raise_error FarOutError
          }

          it("logs error") {
            expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside re-raising!][1]").once
            expect do
              TransactionableIceCream.new.raise_something(error: FarOutError, outside_reraisable_errors: FarOutError)
            end.to raise_error FarOutError
          }

          context "with lock" do
            it("raises") {
              expect do
                TransactionableIceCream.new.raise_something(
                  error: FarOutError,
                  outside_reraisable_errors: FarOutError,
                  lock: true,
                )
              end.to raise_error FarOutError
            }

            it("logs error") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside re-raising!][1]").once
              expect do
                TransactionableIceCream.new.raise_something(
                  error: FarOutError,
                  outside_reraisable_errors: FarOutError,
                  lock: true,
                )
              end.to raise_error FarOutError
            }
          end
        end

        context "retriable" do
          context "not nested" do
            it("does not raise") {
              expect do
                TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError)
              end.not_to raise_error
            }

            it("is fail") {
              tresult = TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError)
              expect(tresult.fail?).to be true
            }

            it("has diagnostic information") {
              tresult = TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError)
              expect(tresult.to_h).to eq({
                attempt: 2,
                result: "fail",
                type: "retriable",
                context: "inside",
                nested: false,
                error: "FarOutError",
                message: "FarOutError",
              })
            }

            it("logs both attempts") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside][1]").once
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside][2]").once
              TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError)
            }

            context "with lock" do
              it("does not raise") {
                expect do
                  TransactionableIceCream.new.raise_something(
                    error: FarOutError,
                    retriable_errors: FarOutError,
                    lock: true,
                  )
                end.not_to raise_error
              }

              it("is fail") {
                tresult = TransactionableIceCream.new.raise_something(
                  error: FarOutError,
                  retriable_errors: FarOutError,
                  lock: true,
                )
                expect(tresult.fail?).to be true
              }

              it("has diagnostic information") {
                tresult = TransactionableIceCream.new.raise_something(
                  error: FarOutError,
                  retriable_errors: FarOutError,
                  lock: true,
                )
                expect(tresult.to_h).to eq({
                  attempt: 2,
                  result: "fail",
                  type: "retriable",
                  context: "inside",
                  nested: false,
                  error: "FarOutError",
                  message: "FarOutError",
                })
              }

              it("logs both attempts") {
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside][1]").once
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside][2]").once
                TransactionableIceCream.new.raise_something(
                  error: FarOutError,
                  retriable_errors: FarOutError,
                  lock: true,
                )
              }
            end
          end

          context "nested" do
            context "inner block" do
              subject do
                TransactionableIceCream.new.do_block(args: [1]) do
                  TransactionableIceCream.new.raise_something(error: FarOutError, retriable_errors: FarOutError)
                end
              end

              it("does not raise") {
                expect { subject }.not_to raise_error
              }

              it("is fail") {
                expect(subject.fail?).to be true
              }

              it("has diagnostic information") {
                expect(subject.to_h).to eq({
                  attempt: 2,
                  result: "fail",
                  type: "retriable",
                  context: "inside",
                  nested: true,
                  error: "FarOutError",
                  message: "FarOutError",
                })
              }

              it("logs both attempts") {
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested inside][1]").once
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested inside][2]").once
                subject
              }

              context "with lock" do
                subject do
                  TransactionableIceCream.new.do_block(args: [1]) do
                    TransactionableIceCream.new.raise_something(
                      error: FarOutError,
                      retriable_errors: FarOutError,
                      lock: true,
                    )
                  end
                end

                it("does not raise") {
                  expect { subject }.not_to raise_error
                }

                it("is fail") { expect(subject.fail?).to be true }

                it("has diagnostic information") {
                  expect(subject.to_h).to eq({
                    attempt: 2,
                    result: "fail",
                    type: "retriable",
                    context: "inside",
                    nested: true,
                    error: "FarOutError",
                    message: "FarOutError",
                  })
                }

                it("logs both attempts") {
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested inside][1]").once
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested inside][2]").once
                  subject
                }
              end
            end

            context "outer block" do
              subject do
                TransactionableIceCream.new.do_block(args: [1], retriable_errors: FarOutError) do
                  TransactionableIceCream.new.raise_something(error: FarOutError)
                end
              end

              it("does not raise") {
                expect { subject }.not_to raise_error
              }

              it("is fail") {
                expect(subject.fail?).to be true
              }

              it("has diagnostic information") {
                expect(subject.to_h).to eq({
                  attempt: 2,
                  result: "fail",
                  type: "retriable",
                  context: "inside",
                  nested: false,
                  error: "FarOutError",
                  message: "FarOutError",
                })
              }

              context "with lock" do
                subject do
                  TransactionableIceCream.new.do_block(args: [1], retriable_errors: FarOutError, lock: true) do
                    TransactionableIceCream.new.raise_something(error: FarOutError)
                  end
                end

                it("does not raise") {
                  expect { subject }.not_to raise_error
                }

                it("is fail") { expect(subject.fail?).to be true }

                it("has diagnostic information") {
                  expect(subject.to_h).to eq({
                    attempt: 2,
                    result: "fail",
                    type: "retriable",
                    context: "inside",
                    nested: false,
                    error: "FarOutError",
                    message: "FarOutError",
                  })
                }

                it("logs both attempts") {
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside][1]").once
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside][2]").once
                  subject
                }
              end
            end
          end
        end

        context "outside_retriable" do
          context "not nested" do
            it("does not raise") {
              expect do
                TransactionableIceCream.new.raise_something(error: FarOutError, outside_retriable_errors: FarOutError)
              end.not_to raise_error
            }

            it("is fail") {
              tresult = TransactionableIceCream.new.raise_something(
                error: FarOutError,
                outside_retriable_errors: FarOutError,
              )
              expect(tresult.fail?).to be true
            }

            it("has diagnostic information") {
              tresult = TransactionableIceCream.new.raise_something(
                error: FarOutError,
                outside_retriable_errors: FarOutError,
              )
              expect(tresult.to_h).to eq({
                attempt: 2,
                result: "fail",
                type: "retriable",
                context: "outside",
                nested: false,
                error: "FarOutError",
                message: "FarOutError",
              })
            }

            it("logs both attempts") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside][1]").once
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside][2]").once
              TransactionableIceCream.new.raise_something(error: FarOutError, outside_retriable_errors: FarOutError)
            }

            context "with lock" do
              it("does not raise") {
                expect do
                  TransactionableIceCream.new.raise_something(
                    error: FarOutError,
                    outside_retriable_errors: FarOutError,
                    lock: true,
                  )
                end.not_to raise_error
              }

              it("is fail") {
                tresult = TransactionableIceCream.new.raise_something(
                  error: FarOutError,
                  outside_retriable_errors: FarOutError,
                  lock: true,
                )
                expect(tresult.fail?).to be true
              }

              it("has diagnostic information") {
                tresult = TransactionableIceCream.new.raise_something(
                  error: FarOutError,
                  outside_retriable_errors: FarOutError,
                  lock: true,
                )
                expect(tresult.to_h).to eq({
                  attempt: 2,
                  result: "fail",
                  type: "retriable",
                  context: "outside",
                  nested: false,
                  error: "FarOutError",
                  message: "FarOutError",
                })
              }

              it("logs both attempts") {
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside][1]").once
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside][2]").once
                TransactionableIceCream.new.raise_something(
                  error: FarOutError,
                  outside_retriable_errors: FarOutError,
                  lock: true,
                )
              }
            end
          end

          context "nested" do
            context "outer block" do
              subject do
                TransactionableIceCream.new.do_block(args: [1], outside_retriable_errors: FarOutError) do
                  TransactionableIceCream.new.raise_something(error: FarOutError)
                end
              end

              it("does not raise") {
                expect { subject }.not_to raise_error
              }

              it("is fail") {
                expect(subject.fail?).to be true
              }

              it("has diagnostic information") {
                expect(subject.to_h).to eq({
                  attempt: 2,
                  result: "fail",
                  type: "retriable",
                  context: "outside",
                  nested: false,
                  error: "FarOutError",
                  message: "FarOutError",
                })
              }

              context "with lock" do
                subject do
                  TransactionableIceCream.new.do_block(args: [1], outside_retriable_errors: FarOutError, lock: true) do
                    TransactionableIceCream.new.raise_something(error: FarOutError)
                  end
                end

                it("does not raise") {
                  expect { subject }.not_to raise_error
                }

                it("is fail") { expect(subject.fail?).to be true }

                it("has diagnostic information") {
                  expect(subject.to_h).to eq({
                    attempt: 2,
                    result: "fail",
                    type: "retriable",
                    context: "outside",
                    nested: false,
                    error: "FarOutError",
                    message: "FarOutError",
                  })
                }

                it("logs both attempts") {
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside][1]").once
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside][2]").once
                  subject
                }
              end
            end

            context "inner block" do
              subject do
                TransactionableIceCream.new.do_block(args: [1]) do
                  TransactionableIceCream.new.raise_something(error: FarOutError, outside_retriable_errors: FarOutError)
                end
              end

              it("does not raise") {
                expect { subject }.not_to raise_error
              }

              it("is fail") {
                expect(subject.fail?).to be true
              }

              it("has diagnostic information") {
                expect(subject.to_h).to eq({
                  attempt: 2,
                  result: "fail",
                  type: "retriable",
                  context: "outside",
                  nested: true,
                  error: "FarOutError",
                  message: "FarOutError",
                })
              }

              it("logs both attempts") {
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested outside][1]").once
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested outside][2]").once
                subject
              }

              context "with lock" do
                subject do
                  TransactionableIceCream.new.do_block(args: [1]) do
                    TransactionableIceCream.new.raise_something(
                      error: FarOutError,
                      outside_retriable_errors: FarOutError,
                      lock: true,
                    )
                  end
                end

                it("does not raise") {
                  expect { subject }.not_to raise_error
                }

                it("is fail") { expect(subject.fail?).to be true }

                it("has diagnostic information") {
                  expect(subject.to_h).to eq({
                    attempt: 2,
                    result: "fail",
                    type: "retriable",
                    context: "outside",
                    nested: true,
                    error: "FarOutError",
                    message: "FarOutError",
                  })
                }

                it("logs both attempts") {
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested outside][1]").once
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [nested outside][2]").once
                  subject
                }
              end
            end
          end
        end
      end

      context "class level" do
        context "with object provided" do
          let(:object) { TransactionableIceCream.new }

          it("does not raise") {
            expect do
              TransactionableIceCream.raise_something(error: FarOutError, object: object, rescued_errors: FarOutError)
            end.not_to raise_error
          }

          it("is fail") {
            tresult = TransactionableIceCream.raise_something(
              error: FarOutError,
              object: object,
              rescued_errors: FarOutError,
            )
            expect(tresult.fail?).to be true
          }

          it("has diagnostic information") {
            tresult = TransactionableIceCream.raise_something(
              error: FarOutError,
              object: object,
              rescued_errors: FarOutError,
            )
            expect(tresult.to_h).to eq({
              attempt: 1,
              result: "fail",
              type: "needing_added",
              context: "inside",
              nested: false,
              error: "FarOutError",
              message: "FarOutError",
            })
          }

          it("adds error to base") {
            TransactionableIceCream.raise_something(error: FarOutError, object: object, rescued_errors: FarOutError)
            expect(object.errors.full_messages).to eq ["FarOutError"]
          }

          it("logs error") {
            expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside][1]")
            TransactionableIceCream.raise_something(error: FarOutError, object: object, rescued_errors: FarOutError)
          }

          context "with lock" do
            it("does not raise") {
              expect do
                TransactionableIceCream.raise_something(
                  error: FarOutError,
                  object: object,
                  lock: true,
                  rescued_errors: FarOutError,
                )
              end.not_to raise_error
            }

            it("is fail") {
              tresult = TransactionableIceCream.raise_something(
                error: FarOutError,
                object: object,
                lock: true,
                rescued_errors: FarOutError,
              )
              expect(tresult.fail?).to be true
            }

            it("has diagnostic information") {
              tresult = TransactionableIceCream.raise_something(
                error: FarOutError,
                object: object,
                lock: true,
                rescued_errors: FarOutError,
              )
              expect(tresult.to_h).to eq({
                attempt: 1,
                result: "fail",
                type: "needing_added",
                context: "inside",
                nested: false,
                error: "FarOutError",
                message: "FarOutError",
              })
            }

            it("adds error to base") {
              TransactionableIceCream.raise_something(
                error: FarOutError,
                object: object,
                lock: true,
                rescued_errors: FarOutError,
              )
              expect(object.errors.full_messages).to eq ["FarOutError"]
            }

            it("logs error") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside][1]")
              TransactionableIceCream.raise_something(
                error: FarOutError,
                object: object,
                lock: true,
                rescued_errors: FarOutError,
              )
            }
          end
        end

        context "no object provided" do
          it("does not raise") {
            expect do
              TransactionableIceCream.raise_something(error: FarOutError, object: nil, rescued_errors: FarOutError)
            end.not_to raise_error
          }

          it("is fail") {
            tresult = TransactionableIceCream.raise_something(
              error: FarOutError,
              object: nil,
              rescued_errors: FarOutError,
            )
            expect(tresult.fail?).to be true
          }

          it("has diagnostic information") {
            tresult = TransactionableIceCream.raise_something(
              error: FarOutError,
              object: nil,
              rescued_errors: FarOutError,
            )
            expect(tresult.to_h).to eq({
              attempt: 1,
              result: "fail",
              type: "needing_added",
              context: "inside",
              nested: false,
              error: "FarOutError",
              message: "FarOutError",
            })
          }

          it("logs error") {
            expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FarOutError: FarOutError [inside][1]")
            TransactionableIceCream.raise_something(error: FarOutError, object: nil, rescued_errors: FarOutError)
          }

          context "with lock" do
            it("raises") {
              expect do
                TransactionableIceCream.raise_something(error: FarOutError, object: nil, lock: true)
              end.to raise_error ArgumentError, "No object to lock!"
            }

            it("does not log error") {
              expect(TransactionableIceCream.logger).not_to receive(:error)
              expect do
                TransactionableIceCream.raise_something(error: FarOutError, object: nil, lock: true)
              end.to raise_error ArgumentError
            }
          end
        end

        context "reraisable" do
          it("raises") {
            expect do
              TransactionableIceCream.raise_something(error: FarOutError, reraisable_errors: FarOutError)
            end.to raise_error FarOutError
          }

          it("logs error") {
            expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FarOutError: FarOutError [inside re-raising!][1]").once
            expect do
              TransactionableIceCream.raise_something(error: FarOutError, reraisable_errors: FarOutError)
            end.to raise_error FarOutError
          }

          context "with lock" do
            let(:object) { TransactionableIceCream.new }

            it("raises") {
              expect do
                TransactionableIceCream.raise_something(
                  error: FarOutError,
                  reraisable_errors: FarOutError,
                  object: object,
                  lock: true,
                )
              end.to raise_error FarOutError
            }

            it("logs error") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [inside re-raising!][1]").once
              expect do
                TransactionableIceCream.raise_something(
                  error: FarOutError,
                  reraisable_errors: FarOutError,
                  object: object,
                  lock: true,
                )
              end.to raise_error FarOutError
            }
          end
        end

        context "outside_reraisable" do
          it("raises") {
            expect do
              TransactionableIceCream.raise_something(error: FarOutError, outside_reraisable_errors: FarOutError)
            end.to raise_error FarOutError
          }

          it("logs error") {
            expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FarOutError: FarOutError [outside re-raising!][1]").once
            expect do
              TransactionableIceCream.raise_something(error: FarOutError, outside_reraisable_errors: FarOutError)
            end.to raise_error FarOutError
          }

          context "with lock" do
            let(:object) { TransactionableIceCream.new }

            it("raises") {
              expect do
                TransactionableIceCream.raise_something(
                  error: FarOutError,
                  outside_reraisable_errors: FarOutError,
                  object: object,
                  lock: true,
                )
              end.to raise_error FarOutError
            }

            it("logs error") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] On TransactionableIceCream FarOutError: FarOutError [outside re-raising!][1]").once
              expect do
                TransactionableIceCream.raise_something(
                  error: FarOutError,
                  outside_reraisable_errors: FarOutError,
                  object: object,
                  lock: true,
                )
              end.to raise_error FarOutError
            }
          end
        end

        context "retriable" do
          context "not nested" do
            it("does not raise") {
              expect do
                TransactionableIceCream.raise_something(error: FarOutError, retriable_errors: FarOutError)
              end.not_to raise_error
            }

            it("is fail") {
              tresult = TransactionableIceCream.raise_something(error: FarOutError, retriable_errors: FarOutError)
              expect(tresult.fail?).to be true
            }

            it("has diagnostic information") {
              tresult = TransactionableIceCream.raise_something(error: FarOutError, retriable_errors: FarOutError)
              expect(tresult.to_h).to eq({
                attempt: 2,
                result: "fail",
                type: "retriable",
                context: "inside",
                nested: false,
                error: "FarOutError",
                message: "FarOutError",
              })
            }

            it("logs both attempts") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FarOutError: FarOutError [inside][1]").once
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FarOutError: FarOutError [inside][2]").once
              TransactionableIceCream.raise_something(error: FarOutError, retriable_errors: FarOutError)
            }
          end

          context "nested" do
            context "inner block" do
              subject do
                TransactionableIceCream.do_block(args: [1]) do
                  TransactionableIceCream.raise_something(error: FarOutError, retriable_errors: FarOutError)
                end
              end

              it("does not raise") {
                expect { subject }.not_to raise_error
              }

              it("is fail") {
                expect(subject.fail?).to be true
              }

              it("has diagnostic information") {
                expect(subject.to_h).to eq({
                  attempt: 2,
                  result: "fail",
                  type: "retriable",
                  context: "inside",
                  nested: true,
                  error: "FarOutError",
                  message: "FarOutError",
                })
              }

              it("logs both attempts") {
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FarOutError: FarOutError [nested inside][1]").once
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FarOutError: FarOutError [nested inside][2]").once
                subject
              }
            end

            context "outer block" do
              subject do
                TransactionableIceCream.do_block(args: [1], retriable_errors: FarOutError) do
                  TransactionableIceCream.raise_something(error: FarOutError)
                end
              end

              it("does not raise") {
                expect { subject }.not_to raise_error
              }

              it("is fail") {
                expect(subject.fail?).to be true
              }

              it("has diagnostic information") {
                expect(subject.to_h).to eq({
                  attempt: 2,
                  result: "fail",
                  type: "retriable",
                  context: "inside",
                  nested: false,
                  error: "FarOutError",
                  message: "FarOutError",
                })
              }
            end
          end
        end

        context "outside_retriable" do
          context "not nested" do
            it("does not raise") {
              expect do
                TransactionableIceCream.raise_something(error: FarOutError, outside_retriable_errors: FarOutError)
              end.not_to raise_error
            }

            it("is fail") {
              tresult = TransactionableIceCream.raise_something(
                error: FarOutError,
                outside_retriable_errors: FarOutError,
              )
              expect(tresult.fail?).to be true
            }

            it("has diagnostic information") {
              tresult = TransactionableIceCream.raise_something(
                error: FarOutError,
                outside_retriable_errors: FarOutError,
              )
              expect(tresult.to_h).to eq({
                attempt: 2,
                result: "fail",
                type: "retriable",
                context: "outside",
                nested: false,
                error: "FarOutError",
                message: "FarOutError",
              })
            }

            it("logs both attempts") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FarOutError: FarOutError [outside][1]").once
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FarOutError: FarOutError [outside][2]").once
              TransactionableIceCream.raise_something(error: FarOutError, outside_retriable_errors: FarOutError)
            }
          end

          context "nested" do
            context "outer block" do
              subject do
                TransactionableIceCream.do_block(args: [1], outside_retriable_errors: FarOutError) do
                  TransactionableIceCream.raise_something(error: FarOutError)
                end
              end

              it("does not raise") {
                expect { subject }.not_to raise_error
              }

              it("is fail") {
                expect(subject.fail?).to be true
              }

              it("has diagnostic information") {
                expect(subject.to_h).to eq({
                  attempt: 2,
                  result: "fail",
                  type: "retriable",
                  context: "outside",
                  nested: false,
                  error: "FarOutError",
                  message: "FarOutError",
                })
              }
            end

            context "inner block" do
              subject do
                TransactionableIceCream.do_block(args: [1]) do
                  TransactionableIceCream.raise_something(error: FarOutError, outside_retriable_errors: FarOutError)
                end
              end

              it("does not raise") {
                expect { subject }.not_to raise_error
              }

              it("is fail") {
                expect(subject.fail?).to be true
              }

              it("has diagnostic information") {
                expect(subject.to_h).to eq({
                  attempt: 2,
                  result: "fail",
                  type: "retriable",
                  context: "outside",
                  nested: true,
                  error: "FarOutError",
                  message: "FarOutError",
                })
              }

              it("logs both attempts") {
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FarOutError: FarOutError [nested outside][1]").once
                expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FarOutError: FarOutError [nested outside][2]").once
                subject
              }
            end
          end
        end

        context "passing retry context" do
          it("does not raise when both are retried or rescued") {
            expect do
              TransactionableIceCream.do_switch(
                args: "fish",
                retriable_errors: FirstTimeError,
                rescued_errors: OnRetryError,
              )
            end.not_to raise_error
          }

          it("is fail") {
            tresult = TransactionableIceCream.do_switch(
              args: "wolf",
              retriable_errors: FirstTimeError,
              rescued_errors: OnRetryError,
            )
            expect(tresult.fail?).to be true
          }

          it("has diagnostic information") {
            tresult = TransactionableIceCream.do_switch(
              args: "wolf",
              retriable_errors: FirstTimeError,
              rescued_errors: OnRetryError,
            )
            expect(tresult.to_h).to eq({
              attempt: 2,
              result: "fail",
              type: "needing_added",
              context: "inside",
              nested: false,
              error: "OnRetryError",
              message: "it is a retry with wolf",
            })
          }

          context "second error is not retriable or rescuable" do
            it("logs first attempt, then raises") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FirstTimeError: it is the first time with bear [inside][1]").once
              expect do
                TransactionableIceCream.do_switch(args: "bear", retriable_errors: FirstTimeError)
              end.to raise_error(OnRetryError, "it is a retry with bear")
            }
          end

          context "second error is retriable" do
            it("logs both attempts, and rescues") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FirstTimeError: it is the first time with bear [inside][1]").once
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] OnRetryError: it is a retry with bear [inside][2]").once
              TransactionableIceCream.do_switch(args: "bear", retriable_errors: [FirstTimeError, OnRetryError])
            }
          end

          context "second error is rescuable" do
            it("logs both attempts, and rescues") {
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FirstTimeError: it is the first time with bear [inside][1]").once
              expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] OnRetryError: it is a retry with bear [inside][2]").once
              TransactionableIceCream.do_switch(
                args: "bear",
                retriable_errors: FirstTimeError,
                rescued_errors: OnRetryError,
              )
            }
          end

          context "outside_retriable" do
            context "not nested" do
              it("does not raise") {
                expect do
                  TransactionableIceCream.do_switch(
                    args: "fox",
                    outside_retriable_errors: FirstTimeError,
                    outside_rescued_errors: OnRetryError,
                  )
                end.not_to raise_error
              }

              it("is fail") {
                tresult = TransactionableIceCream.do_switch(
                  args: "turtle",
                  outside_retriable_errors: FirstTimeError,
                  outside_rescued_errors: OnRetryError,
                )
                expect(tresult.fail?).to be true
              }

              it("has diagnostic information") {
                tresult = TransactionableIceCream.do_switch(
                  args: "turtle",
                  outside_retriable_errors: FirstTimeError,
                  outside_rescued_errors: OnRetryError,
                )
                expect(tresult.to_h).to eq({
                  attempt: 2,
                  result: "fail",
                  type: "needing_added",
                  context: "outside",
                  nested: false,
                  error: "OnRetryError",
                  message: "it is a retry with turtle",
                })
              }

              context "second error is not retriable or rescuable" do
                it("logs first attempt, then raises") {
                  expect(TransactionableIceCream.logger).to receive(:error).with("[TransactionableIceCream.transaction_wrapper] FirstTimeError: it is the first time with bird [outside][1]").once
                  expect do
                    TransactionableIceCream.do_switch(args: "bird", outside_retriable_errors: FirstTimeError)
                  end.to raise_error(OnRetryError, "it is a retry with bird")
                }
              end
            end
          end
        end
      end
    end
  end
end
