# frozen_string_literal: true

ruby_version = Gem::Version.new(RUBY_VERSION)
actual_version = lambda do |major, minor|
  actual = Gem::Version.new(ruby_version)
  major == actual.segments[0] && minor == actual.segments[1] && RUBY_ENGINE == "ruby"
end
coverage = actual_version.call(2, 6)

if coverage
  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/lib/activerecord/transactionable/version.rb"

    if ENV["CI"]
      # Disambiguate individual test runs
      command_name "#{ENV["GITHUB_WORKFLOW"]} Job #{ENV["GITHUB_RUN_ID"]}:#{ENV["GITHUB_RUN_NUMBER"]}"
      formatters = []
      formatters << SimpleCov::Formatter::HTMLFormatter
      formatters << SimpleCov::Formatter::CoberturaFormatter
      formatters << SimpleCov::Formatter::JSONFormatter # For CodeClimate
      formatters << SimpleCov::Formatter::Codecov # For CodeCov
      formatter SimpleCov::Formatter::MultiFormatter.new(formatters)
    else
      # Use default
      formatter SimpleCov::Formatter::HTMLFormatter
    end

    track_files "**/*.rb"
  end
else
  puts "Not running coverage on #{RUBY_ENGINE} #{RUBY_VERSION}"
end
