require "activerecord/transactionable/version"
require "active_model"
require "active_record"
# apparently needed for Rails 4.0 compatibility with rspec, when
#   this gem is loaded before the rails gem by bundler, as will happen when you
#   keep your Gemfile sorted alphabetically.
require "active_record/validations"

module Activerecord # Note lowercase "r" in Activerecord (different namespace than rails' module)
  # SRP: Provides an example of correct behavior for wrapping transactions.
  # NOTE: Rails' transactions are per-database connection, not per-model, nor per-instance,
  #       see: http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html
  module Transactionable
    extend ActiveSupport::Concern

    DEFAULT_ERRORS_TO_HANDLE_INSIDE_TRANSACTION = []
    DEFAULT_ERRORS_PREPARE_ON_SELF_INSIDE = []
    DEFAULT_ERRORS_TO_HANDLE_OUTSIDE_TRANSACTION = [ ActiveRecord::RecordInvalid ]
    DEFAULT_ERRORS_PREPARE_ON_SELF_OUTSIDE = [ ActiveRecord::RecordInvalid ]
    # These errors (and possibly others) will invalidate the transaction (on PostgreSQL and possibly other databases).
    # This means that if you did rescue them inside a transaction (or a nested transaction) all subsequent queries would fail.
    ERRORS_TO_DISALLOW_INSIDE_TRANSACTION = [
        ActiveRecord::RecordInvalid,
        ActiveRecord::StatementInvalid,
        ActiveRecord::RecordNotUnique
    ].freeze
    # http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-transaction
    TRANSACTION_METHOD_ARG_NAMES = [
        :requires_new,
        :isolation,
        :joinable
    ].freeze
    INSIDE_TRANSACTION_ERROR_HANDLERS = [
        :rescued_errors,
        :prepared_errors,
        :retriable_errors,
        :reraisable_errors
    ].freeze
    OUTSIDE_TRANSACTION_ERROR_HANDLERS = [
        :outside_rescued_errors,
        :outside_prepared_errors,
        :outside_retriable_errors,
        :outside_reraisable_errors
    ].freeze
    INSIDE_CONTEXT = "inside".freeze
    OUTSIDE_CONTEXT = "outside".freeze

    def transaction_wrapper(**args)
      self.class.transaction_wrapper(object: self, **args) do
        yield
      end
    end

    module ClassMethods
      def transaction_wrapper(object: nil, **args)
        lock = args.delete(:lock)
        inside_args = extract_args(args, INSIDE_TRANSACTION_ERROR_HANDLERS)
        outside_args = extract_args(args, OUTSIDE_TRANSACTION_ERROR_HANDLERS)
        transaction_open = ActiveRecord::Base.connection.transaction_open?
        raise ArgumentError, "#{self} does not know how to handle arguments: #{args.keys.inspect}" unless args.keys.empty?
        if ERRORS_TO_DISALLOW_INSIDE_TRANSACTION.detect { |error| inside_args.values.include?(error) }
          raise ArgumentError, "#{self} should not rescue #{ERRORS_TO_DISALLOW_INSIDE_TRANSACTION.inspect} inside a transaction: #{args.keys.inspect}"
        end
        transaction_args = extract_args(args, TRANSACTION_METHOD_ARG_NAMES)
        if transaction_open
          unless transaction_args[:require_new]
            transaction_args[:require_new] = true
            logger.warn("[#{self}.transaction_wrapper] Opening a nested transaction. Setting require_new: true")
          else
            logger.debug("[#{self}.transaction_wrapper] Will start a nested transaction.")
          end
          run_inside_transaction_block(transaction_args: transaction_args, inside_args: inside_args, lock: lock, transaction_open: transaction_open, object: object) do
            yield
          end
        else
          puts "what 1 #{__method__}, transaction_open: #{transaction_open}"
          error_handler_outside_transaction(object: object, transaction_open: transaction_open, **outside_args) do
            puts "what 1.2 #{__method__}, transaction_open: #{transaction_open}"
            run_inside_transaction_block(transaction_args: transaction_args, inside_args: inside_args, lock: lock, transaction_open: transaction_open, object: object) do
              puts "what 1.3 #{__method__}, transaction_open: #{transaction_open}"
              yield
            end
          end
        end
      end

      private

      def run_inside_transaction_block(transaction_args:, inside_args:, lock:, transaction_open:, object: nil)
        if object
          if lock
            # Note: with_lock will reload object!
            # Note: with_lock does not accept arguments like transaction does.
            object.with_lock do
              puts "what 4.a #{__method__}, transaction_open: #{transaction_open}"
              error_handler_inside_transaction(object: object, transaction_open: transaction_open, **inside_args) do
                puts "what 4.a.1 #{__method__}, transaction_open: #{transaction_open}"
                yield
              end
            end
          else
            object.transaction(**transaction_args) do
              puts "what 4.b #{__method__}, transaction_open: #{transaction_open}"
              error_handler_inside_transaction(object: object, transaction_open: transaction_open, **inside_args) do
                puts "what 4.b.1 #{__method__}, transaction_open: #{transaction_open}"
                yield
              end
            end
          end
        else
          raise ArgumentError, "No object to lock!" if lock
          ActiveRecord::Base.transaction(**transaction_args) do
            puts "what 4.c #{__method__}, transaction_open: #{transaction_open}"
            error_handler_inside_transaction(object: object, transaction_open: transaction_open, **inside_args) do
              puts "what 4.c.1 #{__method__}, transaction_open: #{transaction_open}"
              yield
            end
          end
        end
      end

      # returns a hash of the arguments to the ActiveRecord::ConnectionAdapters::DatabaseStatements#transaction method
      def extract_args(args, arg_names)
        arg_names.each_with_object({}) do |key, hash|
          hash[key] = args.delete(key)
        end
      end

      def error_handler_inside_transaction(object: nil, transaction_open:, **args)
        puts "what 5 #{__method__}, transaction_open: #{transaction_open}"
        rescued_errors = Array(args[:rescued_errors])
        prepared_errors = Array(args[:prepared_errors])
        retriable_errors = Array(args[:retriable_errors])
        reraisable_errors = Array(args[:reraisable_errors])
        rescued_errors.concat(DEFAULT_ERRORS_TO_HANDLE_INSIDE_TRANSACTION)
        prepared_errors.concat(DEFAULT_ERRORS_PREPARE_ON_SELF_INSIDE)
        already_been_added_to_self, needing_added_to_self = rescued_errors.partition {|error_class| prepared_errors.include?(error_class)}
        local_context = INSIDE_CONTEXT
        run_block_with_retry(object, local_context, transaction_open, retriable_errors, reraisable_errors, already_been_added_to_self, needing_added_to_self) do
          puts "what 5.1 #{__method__}, transaction_open: #{transaction_open}"
          yield
        end
      end

      def error_handler_outside_transaction(object: nil, transaction_open:, **args)
        puts "what 2.1 #{__method__}, transaction_open: #{transaction_open}"
        rescued_errors = Array(args[:outside_rescued_errors])
        prepared_errors = Array(args[:outside_prepared_errors])
        retriable_errors = Array(args[:outside_retriable_errors])
        reraisable_errors = Array(args[:outside_reraisable_errors])
        rescued_errors.concat(DEFAULT_ERRORS_TO_HANDLE_OUTSIDE_TRANSACTION)
        prepared_errors.concat(DEFAULT_ERRORS_PREPARE_ON_SELF_OUTSIDE)
        already_been_added_to_self, needing_added_to_self = rescued_errors.partition {|error_class| prepared_errors.include?(error_class)}
        local_context = OUTSIDE_CONTEXT
        run_block_with_retry(object, local_context, transaction_open, retriable_errors, reraisable_errors, already_been_added_to_self, needing_added_to_self) do
          puts "what 2.2 #{__method__}, transaction_open: #{transaction_open}"
          yield
        end
      end

      def run_block_with_retry(object, local_context, transaction_open, retriable_errors, reraisable_errors, already_been_added_to_self, needing_added_to_self)
        puts "what 3.1 #{__method__}: local_context: #{local_context}, transaction_open: #{transaction_open}"
        re_try = false
        result = begin
          # If the block we yield to here raises an error that is not caught below the `true` will not get hit.
          # If the error is rescued higher up, like where the transaction in active record
          #   rescues ActiveRecord::Rollback without re-raising, then transaction_wrapper will return nil
          # If the error is not rescued higher up the error will continue to bubble
          # If we were already inside a transaction, such that this one is nested,
          #   then the result of the yield is what we want to return, to preserve the innermost result
          result = yield
          # When in the outside context we need to preserve the inside result so it bubles up unmolested with the "meaningful" result of the transaction.
          if transaction_open || local_context == OUTSIDE_CONTEXT
            puts "what 3.2.a preserving: #{result.inspect}, local_context: #{local_context}, transaction_open: #{transaction_open}"
            result # <= preserve the meaningful return value.  Meaning: transaction succeeded, no errors raised
          else
            puts "what 3.2.b no errors! local_context: #{local_context}, transaction_open: #{transaction_open}"
            true # <= make the return value meaningful.  Meaning: transaction succeeded, no errors raised
          end
        rescue *reraisable_errors => error
          # This has highest precedence because raising is the most critical functionality of a raised error to keep
          #   if that is in the intended behavior, and this way a specific child of StandardError can be reraised while
          #   the parent can still be caught and added to self.errors
          # Also adds the error to the object if there is an object.
          transaction_error_logger(object: object, error: error, add_to: nil, additional_message: " [#{transaction_open ? 'nested ' : ''}#{local_context} re-raising!]")
          puts "what 3.2.c reraisable local_context: #{local_context}, transaction_open: #{transaction_open}"
          raise error
        rescue *retriable_errors => error
          # This will re-run the begin block above
          # WARNING: If the same error keeps getting thrown this would infinitely recurse!
          #          To avoid the infinite recursion, we track the retry state
          if re_try
            transaction_error_logger(object: object, error: error, additional_message: " [#{transaction_open ? 'nested ' : ''}#{local_context} 2nd attempt]")
            puts "what 3.2.e post-retry local_context: #{local_context}, transaction_open: #{transaction_open}"
            false # <= make the return value meaningful.  Meaning is: transaction failed after two attempts
          else
            re_try = true
            # Not adding error to base when retrying, because otherwise the added error may
            #   prevent the subsequent save from working, in a catch-22
            transaction_error_logger(object: object, error: error, add_to: nil, additional_message: " [#{transaction_open ? 'nested ' : ''}#{local_context} 1st attempt]")
            puts "what 3.2.d pre-retry local_context: #{local_context}, transaction_open: #{transaction_open}"
            retry
          end
        rescue *already_been_added_to_self => error
          # ActiveRecord::RecordInvalid, when done correctly, will have already added the error to object.
          puts "what 3.2.f already: local_context: #{local_context}, transaction_open: #{transaction_open}"
          transaction_error_logger(object: nil, error: error, additional_message: " [#{transaction_open ? 'nested ' : ''}#{local_context}]")
          false # <= make the return value meaningful.  Meaning is: transaction failed
        rescue *needing_added_to_self => error
          puts "what 3.2.g needing: local_context: #{local_context}, transaction_open: #{transaction_open}"
          transaction_error_logger(object: object, error: error, additional_message: " [#{transaction_open ? 'nested ' : ''}#{local_context}]")
          false # <= make the return value meaningful.  Meaning is: transaction failed
        end
        puts "what 3.3 result: #{result.inspect}"
        result
      end

      def transaction_error_logger(object:, error:, add_to: :base, additional_message: nil)
        # Ruby arguments, like object, are passed by reference,
        #   so this update to errors will be available to the caller
        if object.nil?
          # when a transaction wraps a bunch of CRUD actions,
          #   the specific record that caused the ActiveRecord::RecordInvalid error may be out of scope
          # Ideally you would rewrite the caller to call transaction_wrapper on a single record (even if updates happen on other records)
          logger.error("[#{self}.transaction_wrapper] #{error.class}: #{error.message}#{additional_message}")
          puts("[#{self}.transaction_wrapper] #{error.class}: #{error.message}#{additional_message}")
        else
          logger.error("[#{self}.transaction_wrapper] On #{object.class} #{error.class}: #{error.message}#{additional_message}")
          puts("[#{self}.transaction_wrapper] On #{object.class} #{error.class}: #{error.message}#{additional_message}")
          object.errors.add(add_to, error.message) unless add_to.nil?
        end
      end
    end
  end
end
