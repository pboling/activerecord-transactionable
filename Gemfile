# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# So the gem can run the simple test suite against the raw bundled gems without the complex BUNDLE_GEMFILE setup
gem "sqlite3", platforms: [:ruby]

# Specify your gem's dependencies in activerecord-transactionable.gemspec
gemspec
