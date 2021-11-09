# frozen_string_literal: true

%w[
  bundler/gem_tasks
  rake/testtask
  rspec/core/rake_task
  fileutils
].each { |f| require f }

Bundler::GemHelper.install_tasks

RSpec::Core::RakeTask.new(:spec)
desc "alias spec => test"
task test: :spec

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  task :rubocop do
    warn "RuboCop is disabled on Ruby #{RUBY_VERSION}"
  end
end

task default: %i[spec rubocop]
