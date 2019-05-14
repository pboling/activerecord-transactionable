source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

group :test do
  gem 'byebug', '~> 10', platform: :mri, require: false
  gem 'pry', '~> 0', platform: :mri, require: false
  gem 'pry-byebug', '~> 3', platform: :mri, require: false
  gem 'rubocop', '~> 0.61.1'
  gem 'rubocop-rspec', '~> 1.33.0'
  gem 'simplecov', '~> 0', require: false
end

# So the gem can run the simple test suite against the raw bundled gems without the complex BUNDLE_GEMFILE setup
gem 'sqlite3', platforms: [:ruby]

# Specify your gem's dependencies in activerecord-transactionable.gemspec
gemspec
