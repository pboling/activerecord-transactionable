require "activerecord/transactionable/version"
require "active_model"
require "active_record"

module Activerecord
  # SRP: Provides an example of correct behavior for wrapping transactions.
  # NOTE: Rails' transactions are per-database connection, not per-model, nor per-instance,
  #       see: http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html
  module Transactionable
    extend ActiveSupport::Concern

    DEFAULT_ERRORS_TO_HANDLE = [ActiveRecord::RecordInvalid]
    DEFAULT_ERRORS_WHICH_PREPARE_ERRORS_ON_SELF = [ActiveRecord::RecordInvalid]

    def transaction_wrapper(**args)
      self.class.transaction_wrapper(object: self, **args) do
        yield
      end
    end

    module ClassMethods
      def transaction_wrapper(object: nil, **args)
        rescued_errors = Array(args[:rescued_errors])
        prepared_errors = Array(args[:prepared_errors])
        retriable_errors = Array(args[:retriable_errors])
        reraisable_errors = Array(args[:reraisable_errors])
        rescued_errors.concat(DEFAULT_ERRORS_TO_HANDLE)
        prepared_errors.concat(DEFAULT_ERRORS_WHICH_PREPARE_ERRORS_ON_SELF)
        already_been_added_to_self, needing_added_to_self = rescued_errors.partition {|error_class| prepared_errors.include?(error_class)}
        re_try = false
        begin
          ActiveRecord::Base.transaction do
            yield
          end
          true # <= make the return value meaningful.  Meaning is either: transaction succeeded, OR raised ActiveRecord::Rollback
        rescue *reraisable_errors => error
          # This has highest precedence because raising is the most critical functionality of a raised error to keep
          #   if that is in the intended behavior, and this way a specific child of StandardError can be reraised while
          #   the parent can still be caught and added to self.errors
          # Also adds the error to the object if there is an object.
          transaction_error_logger(object: object, error: error, add_to: nil, additional_message: " [re-raising!]")
          raise error
        rescue *retriable_errors => error
          # This will re-run the begin block above
          # WARNING: If the same error keeps getting thrown this would infinitely recurse!
          #          To avoid the infinite recursion, we track the retry state
          if re_try
            transaction_error_logger(object: object, error: error, additional_message: " [2nd attempt]")
            false # <= make the return value meaningful.  Meaning is: transaction failed after two attempts
          else
            re_try = true
            # Not adding error to base when retrying, because otherwise the added error may
            #   prevent the subsequent save from working, in a catch-22
            transaction_error_logger(object: object, error: error, add_to: nil, additional_message: " [1st attempt]")
            retry
          end
        rescue *already_been_added_to_self => error
          # ActiveRecord::RecordInvalid, when done correctly, will have already added the error to object.
          transaction_error_logger(object: nil, error: error, additional_message: nil)
          false # <= make the return value meaningful.  Meaning is: transaction failed
        rescue *needing_added_to_self => error
          transaction_error_logger(object: object, error: error, additional_message: nil)
          false # <= make the return value meaningful.  Meaning is: transaction failed
        end
      end

      def transaction_error_logger(object:, error:, add_to: :base, additional_message: nil)
        # Ruby arguments, like object, are passed by reference,
        #   so this update to errors will be available to the caller
        if object.nil?
          # when a transaction wraps a bunch of CRUD actions,
          #   the specific record that caused the ActiveRecord::RecordInvalid error may be out of scope
          # Ideally you would rewrite the caller to call transaction_wrapper on a single record (even if updates happen on other records)
          logger.error("[#{self}.transaction_wrapper] #{error.class}: #{error.message}#{additional_message}")
        else
          logger.error("[#{self}.transaction_wrapper] On #{object.class} #{error.class}: #{error.message}#{additional_message}")
          object.errors.add(add_to, error.message) unless add_to.nil?
        end
      end
    end

  end
end
