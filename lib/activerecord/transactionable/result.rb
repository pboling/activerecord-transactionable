module Activerecord
  module Transactionable
    class Result
      attr_reader :value
      def initialize(value)
        @value = value
      end
      
      def fail?
        value == false
      end
      
      def success?
        value == true
      end
    end
  end
end
