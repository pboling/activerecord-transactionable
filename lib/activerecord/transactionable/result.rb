module Activerecord
  module Transactionable
    class Result
      attr_reader :value, :result, :error, :type, :context, :nested
      def initialize(value, context:, transaction_open:, error: nil, type: nil)
        @value = value
        @result = fail? ? 'fail' : 'success'
        @context = context
        @nested = transaction_open ? true : false
        @error = error
        @type = type
      end

      def fail?
        value == false
      end

      def success?
        value == true
      end

      def to_h
        diagnostic_data = {
            result: result,
            type: type,
            context: context,
            nested: nested
        }
        diagnostic_data.merge!(
          error: error.class.to_s,
          message: error.message,
        ) if error
        diagnostic_data
      end

      def to_s
        to_h.to_s
      end
    end
  end
end
