# frozen_string_literal: true

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/lib/activerecord/transactionable/version.rb"

  if ENV["CI"]
    # Disambiguate individual test runs
    command_name "#{ENV["GITHUB_WORKFLOW"]} Job #{ENV["GITHUB_RUN_ID"]}:#{ENV["GITHUB_RUN_NUMBER"]}"
    formatters = []
    formatters << SimpleCov::Formatter::HTMLFormatter
    formatters << SimpleCov::Formatter::JSONFormatter # For CodeClimate
    formatters << SimpleCov::Formatter::CoberturaFormatter # For CodeCov
    formatter SimpleCov::Formatter::MultiFormatter.new(formatters)
  else
    # Use default
    formatter SimpleCov::Formatter::HTMLFormatter
  end

  track_files "**/*.rb"
end
