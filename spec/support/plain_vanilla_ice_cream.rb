class PlainVanillaIceCream < ActiveRecord::Base
  class << self
    attr_accessor :internal_logger

    def do_block(*args)
      yield(*args) if block_given?
    end

    def do_something(*_args)
      1
    end

    def raise_something(error)
      raise error
    end

    def logger
      self.internal_logger ||= NullLogger.new
    end

    def log_with(alt_logger)
      old_logger = internal_logger.deep_dup
      self.internal_logger = alt_logger
      yield
      self.internal_logger = old_logger
    end
  end

  attr_accessor :topping

  validates_presence_of :topping
  def raise_something(error)
    raise error
  end

  def do_something(*_args)
    1
  end

  def do_block(*args)
    result = yield(*args) if block_given?
    result
  end

  def logger
    self.class.logger
  end
end
