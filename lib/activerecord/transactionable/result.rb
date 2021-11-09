# frozen_string_literal: true

module Activerecord
  module Transactionable
    class Result
      attr_reader :value, :result, :error, :type, :context, :nested, :attempt

      def initialize(value, context:, transaction_open:, attempt:, error: nil, type: nil)
        @value = value
        @result = fail? ? "fail" : "success"
        @context = context
        @nested = transaction_open ? true : false
        @attempt = attempt
        @error = error
        @type = type
      end

      def fail?
        value == false
      end

      def success?
        value == true
      end

      def to_h(skip_error: nil)
        diagnostic_data = {
          result: result,
          type: type,
          context: context,
          nested: nested,
          attempt: attempt
        }
        if !skip_error && error
          diagnostic_data[:error] = error.class.to_s
          diagnostic_data[:message] = error.message
        end
        diagnostic_data
      end

      def to_s(skip_error: nil)
        to_h(skip_error: skip_error).to_s
      end
    end
  end
end
