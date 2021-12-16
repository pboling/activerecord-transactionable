# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "activerecord/transactionable/version"

Gem::Specification.new do |spec|
  spec.name          = "activerecord-transactionable"
  spec.version       = Activerecord::Transactionable::VERSION
  spec.authors       = ["Peter Boling"]
  spec.email         = ["peter.boling@gmail.com"]
  spec.licenses      = ["MIT"]

  spec.summary       = "Do ActiveRecord transactions the right way."
  spec.description   = "Getting transactions right is hard, and this gem makes it easier."
  spec.homepage      = "http://www.railsbling.com/tags/activerecord-transactionable"

  spec.files         = Dir["lib/**/*.rb", "CODE_OF_CONDUCT.md", "CONTRIBUTING.md", "LICENSE", "README.md", "SECURITY.md"]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.5.0"

  ruby_version = Gem::Version.new(RUBY_VERSION)
  minimum_version = ->(version) { ruby_version >= Gem::Version.new(version) && RUBY_ENGINE == "ruby" }
  actual_version = lambda do |major, minor|
    actual = Gem::Version.new(ruby_version)
    major == actual.segments[0] && minor == actual.segments[1] && RUBY_ENGINE == "ruby"
  end
  coverage = actual_version.call(2, 6)
  linting = minimum_version.call("2.6")
  stream = minimum_version.call("2.3")

  spec.add_dependency "activemodel", ">= 4.0.0"
  spec.add_dependency "activerecord", ">= 4.0.0"

  spec.add_development_dependency "byebug", "~> 11.1"
  spec.add_development_dependency "factory_bot", ">= 4.0"
  spec.add_development_dependency "rake", ">= 12.0"
  spec.add_development_dependency "rspec", "~> 3.10"
  spec.add_development_dependency "rspec-benchmark", "~> 0.6"
  spec.add_development_dependency "rspec-block_is_expected", "~> 1.0"
  spec.add_development_dependency "rspec-pending_for", "~> 0.1"
  spec.add_development_dependency "silent_stream", "~> 1.0" if stream
  if linting
    spec.add_development_dependency("rubocop", "~> 1.22")
    spec.add_development_dependency("rubocop-md", "~> 1.0")
    spec.add_development_dependency("rubocop-minitest", "~> 0.15")
    spec.add_development_dependency("rubocop-packaging", "~> 0.5")
    spec.add_development_dependency("rubocop-performance", "~> 1.11")
    spec.add_development_dependency("rubocop-rake", "~> 0.6")
    spec.add_development_dependency("rubocop-rspec", "~> 2.5")
    spec.add_development_dependency("rubocop-thread_safety", "~> 0.4")
  end
  if coverage
    spec.add_development_dependency("codecov", "~> 0.6")
    spec.add_development_dependency("simplecov", "~> 0.21")
    spec.add_development_dependency("simplecov-cobertura", "~> 2.1")
  end
  spec.add_development_dependency "sqlite3", "~> 1"
  spec.add_development_dependency "yard", ">= 0.9.20"
end
