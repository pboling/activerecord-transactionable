# frozen_string_literal: true

ruby_version = Gem::Version.new(RUBY_VERSION)
minimum_version = ->(version) { ruby_version >= Gem::Version.new(version) && RUBY_ENGINE == "ruby" }
coverage = minimum_version.call("2.6")
debug = minimum_version.call("2.4")
eol = minimum_version.call("2.1")

if coverage
  require "simplecov"
  require "simplecov-cobertura"
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter unless ENV["HTML_COVERAGE"] == "true"
end

# External libraries
require "byebug" if debug
require "rspec/block_is_expected"
require "sqlite3" if eol # Not needed on newer versions of sqlite

# This gem
require "activerecord/transactionable"

# Configs
require "config/active_record"
require "config/factory_bot"
require "rspec_config/matchers"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
  end
end
