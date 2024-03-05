# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)
desc "alias spec => test"
task test: :spec

begin
  require "rubocop/lts"
  Rubocop::Lts.install_tasks
rescue LoadError
  puts "Linting not available"
end

task default: %i[spec rubocop_gradual]
