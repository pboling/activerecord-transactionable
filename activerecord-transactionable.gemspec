# frozen_string_literal: true

# Get the GEMFILE_VERSION without *require* "my_gem/version", for code coverage accuracy
# See: https://github.com/simplecov-ruby/simplecov/issues/557#issuecomment-825171399
load "lib/activerecord/transactionable/version.rb"
gem_version = Activerecord::Transactionable::Version::VERSION
Activerecord::Transactionable::Version.send(:remove_const, :VERSION)

Gem::Specification.new do |spec|
  spec.name = "activerecord-transactionable"
  spec.version = gem_version
  spec.authors = ["Peter Boling"]
  spec.email = ["peter.boling@gmail.com"]

  # See CONTRIBUTING.md
  spec.cert_chain = ["certs/pboling.pem"]
  spec.signing_key = File.expand_path("~/.ssh/gem-private_key.pem") if $PROGRAM_NAME.end_with?("gem")

  spec.summary = "Do ActiveRecord transactions the right way."
  spec.description = "Getting transactions right is hard, and this gem makes it easier."
  spec.licenses = ["MIT"]
  spec.required_ruby_version = ">= 2.5.0"

  spec.homepage = "https://github.com/pboling/#{spec.name}"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/v#{spec.version}"
  # spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/v#{spec.version}/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "https://www.rubydoc.info/gems/#{spec.name}/#{spec.version}"
  spec.metadata["wiki_uri"] = "#{spec.homepage}/wiki"
  spec.metadata["funding_uri"] = "https://liberapay.com/pboling"
  spec.metadata["news_uri"] = "https://www.railsbling.com/tags/activerecord-transactionable"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir[
    "lib/**/*.rb",
    "CODE_OF_CONDUCT.md",
    "CONTRIBUTING.md",
    "LICENSE.txt",
    "README.md",
    "SECURITY.md"
  ]
  spec.bindir = "exe"
  spec.executables = []
  spec.require_paths = ["lib"]

  # Root Gemfile is only for local development only. It is not loaded on CI.
  # On CI we only need the gemspecs' dependencies (including development dependencies).
  # Exceptions, if any, will be found in gemfiles/*.gemfile

  spec.add_dependency("activemodel", ">= 5.2.8.1")
  spec.add_dependency("activerecord", ">= 5.2.8.1")

  # Utilities
  spec.add_dependency("version_gem", "~> 1.1", ">= 1.1.3")
  spec.add_development_dependency("rake", ">= 13.1")

  # Code Coverage
  # CodeCov + GitHub setup is not via gems: https://github.com/marketplace/actions/codecov
  # Minimum Ruby for kettle-soup-cover is 2.7, so we can only add the dependency in gemfiles/*
  # spec.add_development_dependency("kettle-soup-cover", "~> 1.0", ">= 1.0.2")

  # Documentation
  spec.add_development_dependency("kramdown", "~> 2.4")
  spec.add_development_dependency("yard", "~> 0.9", ">= 0.9.34")
  spec.add_development_dependency("yard-junk", "~> 0.0")

  # Linting
  # Minimum Ruby for various linting gems is too high, so we can only add the dependency in gemfiles/*
  # spec.add_development_dependency("rubocop-lts", "~> 14.1", ">= 14.1.1")
  # spec.add_development_dependency("rubocop-packaging", "~> 0.5", ">= 0.5.2")
  # spec.add_development_dependency("rubocop-rspec", "~> 2.10")

  # Testing
  # TODO: factory_bot is locked... Drop lock when minimum Ruby <= 3.0
  #       See: https://github.com/thoughtbot/factory_bot/issues/1627
  spec.add_development_dependency("factory_bot", "6.4.4")
  spec.add_development_dependency("rspec", ">= 3")
  spec.add_development_dependency("rspec-benchmark", "~> 0.6")
  spec.add_development_dependency("rspec-block_is_expected", "~> 1.0", ">= 1.0.5")
  spec.add_development_dependency("rspec_junit_formatter", "~> 0.6")
  spec.add_development_dependency("rspec-pending_for", ">= 0")
  spec.add_development_dependency("silent_stream", ">= 1")

  # Database
  spec.add_development_dependency("sqlite3", "~> 1")
end
