# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in activerecord-transactionable.gemspec
gemspec

platform :mri do
  # Debugging
  gem "byebug", ">= 11"
end

# Coverage
gem "kettle-soup-cover", "~> 1.0", ">= 1.0.2"

# Linting
gem "rubocop-lts", "~> 14.1", ">= 14.1.1"
gem "rubocop-packaging", "~> 0.5", ">= 0.5.2"
gem "rubocop-rspec", "~> 2.10"
