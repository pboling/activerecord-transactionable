# frozen_string_literal: true

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/lib/activerecord/transactionable/version.rb"

  if ENV["CI"]
    # Disambiguate individual test runs
    command_name "#{ENV["GITHUB_WORKFLOW"]} Job #{ENV["GITHUB_RUN_ID"]}:#{ENV["GITHUB_RUN_NUMBER"]}"
  end

  track_files "**/*.rb"
end
