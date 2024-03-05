# frozen_string_literal: true

require "active_record"
require "yaml"
require "logger"
require 'pathname'

test_dir = Pathname.new File.dirname(__FILE__)

class NullLogger < Logger
  def initialize(*args); end

  def add(*args, &block); end
end

FileUtils.mkdir_p 'log'
ActiveRecord::Base.logger = Logger.new("log/test.log")
ActiveRecord::Base.logger.level = Logger::DEBUG

if ActiveRecord.respond_to?(:use_yaml_unsafe_load)
  ActiveRecord.use_yaml_unsafe_load = true
elsif ActiveRecord::Base.respond_to?(:use_yaml_unsafe_load)
  ActiveRecord::Base.use_yaml_unsafe_load = true
end
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.verbose = false
adapter = ENV["DB"] || "sqlite"
yaml_config = YAML.load_file(test_dir.join("database.yml"))[adapter]

# if RUBY_PLATFORM == "java"
#   yaml_config["sqlite"]["adapter"] = "jdbcsqlite3"
#   yaml_config["mysql"]["adapter"] = "jdbcmysql"
#   yaml_config["postgresql"]["adapter"] = "jdbcpostgresql"
# end
config = ActiveRecord::DatabaseConfigurations::HashConfig.new("test", adapter, yaml_config)
ActiveRecord::Base.configurations.configurations << config

# Run specific adapter tests like:
#
#   DB=sqlite rake test:all
#   DB=mysql rake test:all
#   DB=postgresql rake test:all
#
ActiveRecord::Base.establish_connection :test
load("#{File.dirname(__FILE__)}/schema.rb")
