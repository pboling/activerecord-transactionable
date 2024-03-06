require "activerecord/transactionable"

class TransactionableIceCream < PlainVanillaIceCream
  include Activerecord::Transactionable

  class << self
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

    def do_switch(args:, **opts)
      transaction_wrapper(**opts) do |is_retry|
        if is_retry
          raise OnRetryError, "it is a retry with #{args}"
        else
          raise FirstTimeError, "it is the first time with #{args}"
        end
      end
    end

    def do_block(args:, **opts)
      transaction_wrapper(**opts) do
        super(*args) do |_args|
          yield
        end
      end
    end

    def logger
      self.internal_logger ||= NullLogger.new
    end
  end

  def logger
    self.class.logger
  end

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
end
