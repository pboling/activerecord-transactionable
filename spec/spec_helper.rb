# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
begin
  # This does not require "simplecov",
  #   because that has a side-effect of running `.simplecov`
  require "kettle-soup-cover"
rescue LoadError
  puts "Not running code coverage"
end

# External libraries
require "rspec/block_is_expected"
require "rspec/pending_for"
require "rspec-benchmark"
require "silent_stream"

# 3rd Party Lib Configs
require "config/byebug"
require "config/active_record"
require "config/factory_bot"

# RSpec Configs
require "config/rspec/matchers"
require "config/rspec/factory_bot"
require "config/rspec/rspec_block_is_expected"
require "config/rspec/rspec_core"
require "config/rspec/silent_stream"
require "config/rspec/version_gem"

# Support files which do not depend on this gem
require "support/errors"
require "support/plain_vanilla_ice_cream"

# Last thing before this gem is code coverage:
require "simplecov" if defined?(Kettle) && Kettle::Soup::Cover::DO_COV

# This gem
require "activerecord/transactionable"

# Support files which depend on this gem
require "support/transactionable_ice_cream"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
