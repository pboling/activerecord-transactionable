# frozen_string_literal: true

# External gems
require "version_gem"
require "active_model"
require "active_record"
require "active_record/validations"

# This gem
require "activerecord/transactionable/version"
require "activerecord/transactionable/result"

# Note lowercase "r" in Activerecord (different namespace than rails' module)
module Activerecord
  # SRP: Provides an example of correct behavior for wrapping transactions.
  # NOTE: Rails' transactions are per-database connection, not per-model, nor per-instance,
  #       see: http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html
  module Transactionable
    extend ActiveSupport::Concern

    DEFAULT_NUM_RETRY_ATTEMPTS = 2
    DEFAULT_ERRORS_TO_HANDLE_INSIDE_TRANSACTION = [].freeze
    DEFAULT_ERRORS_PREPARE_ON_SELF_INSIDE = [].freeze
    DEFAULT_ERRORS_TO_HANDLE_OUTSIDE_TRANSACTION = [ActiveRecord::RecordInvalid].freeze
    DEFAULT_ERRORS_PREPARE_ON_SELF_OUTSIDE = [ActiveRecord::RecordInvalid].freeze
    # These errors (and possibly others) will invalidate the transaction (on PostgreSQL and possibly other databases).
    # This means that if you did rescue them inside a transaction (or a nested transaction) all subsequent queries would fail.
    ERRORS_TO_DISALLOW_INSIDE_TRANSACTION = [
      ActiveRecord::RecordInvalid,
      ActiveRecord::StatementInvalid,
      ActiveRecord::RecordNotUnique,
    ].freeze
    # http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-transaction
    TRANSACTION_METHOD_ARG_NAMES = %i[
      requires_new
      isolation
      joinable
    ].freeze
    REQUIRES_NEW = TRANSACTION_METHOD_ARG_NAMES[0]
    INSIDE_TRANSACTION_ERROR_HANDLERS = %i[
      rescued_errors
      prepared_errors
      retriable_errors
      reraisable_errors
      num_retry_attempts
    ].freeze
    OUTSIDE_TRANSACTION_ERROR_HANDLERS = %i[
      outside_rescued_errors
      outside_prepared_errors
      outside_retriable_errors
      outside_reraisable_errors
      outside_num_retry_attempts
    ].freeze
    INSIDE_CONTEXT = "inside"
    OUTSIDE_CONTEXT = "outside"

    module ClassMethods
      def transaction_wrapper(object: nil, **args)
        lock = args.delete(:lock)
        inside_args = extract_args(args, INSIDE_TRANSACTION_ERROR_HANDLERS)
        outside_args = extract_args(args, OUTSIDE_TRANSACTION_ERROR_HANDLERS)
        transaction_args = extract_args(args, TRANSACTION_METHOD_ARG_NAMES)
        transaction_open = ActiveRecord::Base.connection.transaction_open?
        unless args.keys.empty?
          raise ArgumentError,
            "#{self} does not know how to handle arguments: #{args.keys.inspect}"
        end
        if ERRORS_TO_DISALLOW_INSIDE_TRANSACTION.detect do |error|
          inside_args.values.flatten.uniq.include?(error)
        end
          raise ArgumentError,
            "#{self} should not rescue #{ERRORS_TO_DISALLOW_INSIDE_TRANSACTION.inspect} inside a transaction: #{inside_args.keys.inspect}"
        end

        if transaction_open
          if transaction_args[REQUIRES_NEW]
            logger.debug("[#{self}.transaction_wrapper] Will start a nested transaction.")
          else
            transaction_args[REQUIRES_NEW] = true
            logger.warn("[#{self}.transaction_wrapper] Opening a nested transaction. Setting #{REQUIRES_NEW}: true")
          end
        end
        error_handler_outside_transaction(
          object: object,
          transaction_open: transaction_open,
          **outside_args,
        ) do |outside_is_retry|
          run_inside_transaction_block(
            transaction_args: transaction_args,
            inside_args: inside_args,
            lock: lock,
            transaction_open: transaction_open,
            object: object,
          ) do |is_retry|
            # regardless of the retry being inside or outside the transaction, it is still a retry.
            yield outside_is_retry || is_retry
          end
        end
      end

      private

      def run_inside_transaction_block(transaction_args:, inside_args:, lock:, transaction_open:, object: nil, &block)
        if object
          if lock
            # NOTE: with_lock will reload object!
            # Note: with_lock does not accept arguments like transaction does.
            object.with_lock do
              error_handler_inside_transaction(
                object: object, transaction_open: transaction_open, **inside_args,
                &block
              )
            end
          else
            object.transaction(**transaction_args) do
              error_handler_inside_transaction(
                object: object, transaction_open: transaction_open, **inside_args,
                &block
              )
            end
          end
        else
          raise ArgumentError, "No object to lock!" if lock

          ActiveRecord::Base.transaction(**transaction_args) do
            error_handler_inside_transaction(object: object, transaction_open: transaction_open, **inside_args, &block)
          end
        end
      end

      # returns a hash of the arguments to the ActiveRecord::ConnectionAdapters::DatabaseStatements#transaction method
      def extract_args(args, arg_names)
        arg_names.each_with_object({}) do |key, hash|
          hash[key] = args.delete(key)
        end
      end

      def error_handler_inside_transaction(transaction_open:, object: nil, **args, &block)
        rescued_errors = Array(args[:rescued_errors])
        prepared_errors = Array(args[:prepared_errors])
        retriable_errors = Array(args[:retriable_errors])
        reraisable_errors = Array(args[:reraisable_errors])
        num_retry_attempts = args[:num_retry_attempts] ? args[:num_retry_attempts].to_i : DEFAULT_NUM_RETRY_ATTEMPTS
        rescued_errors.concat(DEFAULT_ERRORS_TO_HANDLE_INSIDE_TRANSACTION)
        prepared_errors.concat(DEFAULT_ERRORS_PREPARE_ON_SELF_INSIDE)
        already_been_added_to_self, needing_added_to_self = rescued_errors.partition do |error_class|
          prepared_errors.include?(error_class)
        end
        local_context = INSIDE_CONTEXT
        run_block_with_retry(
          object,
          local_context,
          transaction_open,
          retriable_errors,
          reraisable_errors,
          already_been_added_to_self,
          needing_added_to_self,
          num_retry_attempts,
          &block
        )
      end

      def error_handler_outside_transaction(transaction_open:, object: nil, **args, &block)
        rescued_errors = Array(args[:outside_rescued_errors])
        prepared_errors = Array(args[:outside_prepared_errors])
        retriable_errors = Array(args[:outside_retriable_errors])
        reraisable_errors = Array(args[:outside_reraisable_errors])
        num_retry_attempts = args[:outside_num_retry_attempts] ? args[:outside_num_retry_attempts].to_i : DEFAULT_NUM_RETRY_ATTEMPTS
        rescued_errors.concat(DEFAULT_ERRORS_TO_HANDLE_OUTSIDE_TRANSACTION)
        prepared_errors.concat(DEFAULT_ERRORS_PREPARE_ON_SELF_OUTSIDE)
        already_been_added_to_self, needing_added_to_self = rescued_errors.partition do |error_class|
          prepared_errors.include?(error_class)
        end
        local_context = OUTSIDE_CONTEXT
        run_block_with_retry(
          object,
          local_context,
          transaction_open,
          retriable_errors,
          reraisable_errors,
          already_been_added_to_self,
          needing_added_to_self,
          num_retry_attempts,
          &block
        )
      end

      def run_block_with_retry(object, local_context, transaction_open, retriable_errors, reraisable_errors, already_been_added_to_self, needing_added_to_self, num_retry_attempts)
        attempt = 0
        re_try = false
        begin
          attempt += 1
          # If the block we yield to here raises an error that is not caught below the `re_try = true` will not get hit.
          # If the error is rescued higher up, like where the transaction in active record
          #   rescues ActiveRecord::Rollback without re-raising, then transaction_wrapper will return nil
          # If the error is not rescued higher up the error will continue to bubble
          # If we were already inside a transaction, such that this one is nested,
          #   then the result of the yield is what we want to return, to preserve the innermost result
          # We pass the retry state along to yield so that the code implementing
          #   the transaction_wrapper can switch behavior on a retry
          #   (e.g. create => find)
          result = yield ((re_try == false) ? re_try : attempt)
          # When in the outside context we need to preserve the inside result so it bubbles up unmolested with the "meaningful" result of the transaction.
          if result.is_a?(Activerecord::Transactionable::Result)
            result # <= preserve the meaningful return value
          else
            Activerecord::Transactionable::Result.new(true, context: local_context, attempt: attempt, transaction_open: transaction_open) # <= make the return value meaningful.  Meaning: transaction succeeded, no errors raised
          end
        rescue *reraisable_errors => e
          # This has highest precedence because raising is the most critical functionality of a raised error to keep
          #   if that is in the intended behavior, and this way a specific child of StandardError can be reraised while
          #   the parent can still be caught and added to self.errors
          # Also adds the error to the object if there is an object.
          transaction_error_logger(
            object: object,
            error: e,
            result: nil,
            attempt: attempt,
            add_to: nil,
            additional_message: " [#{transaction_open ? "nested " : ""}#{local_context} re-raising!]",
          )
          raise e
        rescue *retriable_errors => e
          # This will re-run the begin block above
          # WARNING: If the same error keeps getting thrown this would infinitely recurse!
          #          To avoid the infinite recursion, we track the retry state
          if attempt >= num_retry_attempts
            result = Activerecord::Transactionable::Result.new(false, context: local_context, transaction_open: transaction_open, error: e, attempt: attempt, type: "retriable") # <= make the return value meaningful.  Meaning is: transaction failed after <attempt> attempts
            transaction_error_logger(
              object: object,
              error: e,
              result: result,
              additional_message: " [#{transaction_open ? "nested " : ""}#{local_context}]",
            )
            result
          else
            re_try = true
            # Not adding error to base when retrying, because otherwise the added error may
            #   prevent the subsequent save from working, in a catch-22
            transaction_error_logger(
              object: object,
              error: e,
              result: nil,
              attempt: attempt,
              add_to: nil,
              additional_message: " [#{transaction_open ? "nested " : ""}#{local_context}]",
            )
            retry
          end
        rescue *already_been_added_to_self => e
          # ActiveRecord::RecordInvalid, when done correctly, will have already added the error to object.
          result = Activerecord::Transactionable::Result.new(false, context: local_context, transaction_open: transaction_open, error: e, attempt: attempt, type: "already_added") # <= make the return value meaningful.  Meaning is: transaction failed
          transaction_error_logger(
            object: nil,
            error: e,
            result: result,
            additional_message: " [#{transaction_open ? "nested " : ""}#{local_context}]",
          )
          result
        rescue *needing_added_to_self => e
          result = Activerecord::Transactionable::Result.new(false, context: local_context, transaction_open: transaction_open, error: e, attempt: attempt, type: "needing_added") # <= make the return value meaningful.  Meaning is: transaction failed
          transaction_error_logger(
            object: object,
            error: e,
            result: result,
            additional_message: " [#{transaction_open ? "nested " : ""}#{local_context}]",
          )
          result
        end
      end

      def transaction_error_logger(object:, error:, result:, attempt: nil, add_to: :base, additional_message: nil, **_opts)
        # Ruby arguments, like object, are passed by reference,
        #   so this update to errors will be available to the caller
        if object.nil?
          # when a transaction wraps a bunch of CRUD actions,
          #   the specific record that caused the ActiveRecord::RecordInvalid error may be out of scope
          # Ideally you would rewrite the caller to call transaction_wrapper on a single record (even if updates happen on other records)
          logger.error("[#{self}.transaction_wrapper] #{error.class}: #{error.message}#{additional_message}[#{attempt || (result && result.to_h[:attempt])}]")
        else
          logger.error("[#{self}.transaction_wrapper] On #{object.class} #{error.class}: #{error.message}#{additional_message}[#{attempt || (result && result.to_h[:attempt])}]")
          object.errors.add(add_to, error.message) unless add_to.nil?
        end
      end
    end

    def transaction_wrapper(**args, &block)
      self.class.transaction_wrapper(object: self, **args, &block)
    end
  end
end

Activerecord::Transactionable::Version.class_eval do
  extend VersionGem::Basic
end
