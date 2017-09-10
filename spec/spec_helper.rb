require "yaml"
require "logger"

require "coveralls"
Coveralls.wear!

# This library
require "activerecord/transactionable"

class NullLogger < Logger
  def initialize(*args)
  end

  def add(*args, &block)
  end
end

ActiveRecord::Base.logger = NullLogger.new
ActiveRecord::Migration.verbose = false

configs = YAML.load_file(File.dirname(__FILE__) + "/database.yml")
if RUBY_PLATFORM == "java"
  configs["sqlite"]["adapter"] = "jdbcsqlite3"
  configs["mysql"]["adapter"] = "jdbcmysql"
  configs["postgresql"]["adapter"] = "jdbcpostgresql"
end
ActiveRecord::Base.configurations = configs

# Run specific adapter tests like:
#
#   DB=sqlite rake test:all
#   DB=mysql rake test:all
#   DB=postgresql rake test:all
#
db_name = (ENV["DB"] || "sqlite").to_sym
ActiveRecord::Base.establish_connection(db_name)
load(File.dirname(__FILE__) + "/schema.rb")
