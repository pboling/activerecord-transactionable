# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "activerecord/transactionable/version"

Gem::Specification.new do |spec|
  spec.name = "activerecord-transactionable"
  spec.version = Activerecord::Transactionable::VERSION
  spec.authors = ["Peter Boling"]
  spec.email = ["peter.boling@gmail.com"]
  spec.licenses = ["MIT"]

  spec.summary = "Do ActiveRecord transactions the right way."
  spec.description = "Getting transactions right is hard, and this gem makes it easier."
  spec.homepage = "http://www.railsbling.com/tags/activerecord-transactionable"

  spec.files = Dir["lib/**/*.rb", "CODE_OF_CONDUCT.md", "CONTRIBUTING.md", "LICENSE", "README.md", "SECURITY.md"]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.5.0"

  spec.add_dependency("activemodel", ">= 5.2.8.1")
  spec.add_dependency("activerecord", ">= 5.2.8.1")

  # Code Coverage
  # CodeCov + GitHub setup is not via gems: https://github.com/marketplace/actions/codecov
  spec.add_development_dependency("kettle-soup-cover", "~> 1.0", ">= 1.0.2")

  # Documentation
  spec.add_development_dependency("kramdown", "~> 2.4")
  spec.add_development_dependency("yard", "~> 0.9", ">= 0.9.34")
  spec.add_development_dependency("yard-junk", "~> 0.0")

  # Linting
  spec.add_development_dependency("rubocop-lts", ">= 14.1.1", "~> 24.0")
  spec.add_development_dependency("rubocop-packaging", "~> 0.5", ">= 0.5.2")
  spec.add_development_dependency("rubocop-rspec", "~> 2.10")

  # Testing
  spec.add_development_dependency("factory_bot", ">= 4.0")
  spec.add_development_dependency("rspec", ">= 3")
  spec.add_development_dependency("rspec-benchmark", "~> 0.6")
  spec.add_development_dependency("rspec-block_is_expected", "~> 1.0", ">= 1.0.5")
  spec.add_development_dependency("rspec_junit_formatter", "~> 0.6")
  spec.add_development_dependency("rspec-pending_for", ">= 0")
  spec.add_development_dependency("silent_stream", ">= 1")

  spec.add_development_dependency("rake", ">= 12.0")
  spec.add_development_dependency("sqlite3", "~> 1")
end
