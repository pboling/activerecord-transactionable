# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
# This does not require "simplecov",
#   because that has a side-effect of running `.simplecov`
require "kettle-soup-cover"

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

# Last thing before this gem is code coverage:
require "simplecov" if Kettle::Soup::Cover::DO_COV

# This gem
require "activerecord/transactionable"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
