# frozen_string_literal: true

ruby_version = Gem::Version.new(RUBY_VERSION)
minimum_version = ->(version) { ruby_version >= Gem::Version.new(version) && RUBY_ENGINE == "ruby" }
coverage = minimum_version.call("2.6")
debug = minimum_version.call("2.4")
stream = minimum_version.call("2.3")

if coverage
  require "simplecov"
  require "simplecov-cobertura"
  require "simplecov_json_formatter"
end

# External libraries
require "byebug" if debug
require "rspec/block_is_expected"
require "rspec-benchmark"
require "silent_stream" if stream

# This gem
require "activerecord/transactionable"

# Configs
require "config/active_record"
require "config/factory_bot"
require "rspec_config/matchers"
require "rspec_config/factory_bot"
require "rspec_config/silent_stream" if stream

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
