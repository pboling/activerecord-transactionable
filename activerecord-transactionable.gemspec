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

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.1.0"

  ruby_version = Gem::Version.new(RUBY_VERSION)
  minimum_version = ->(version) { ruby_version >= Gem::Version.new(version) && RUBY_ENGINE == "ruby" }
  linting = minimum_version.call("2.6")
  coverage = minimum_version.call("2.6")
  debug = minimum_version.call("2.4")

  spec.add_dependency "activemodel", "4.2.11.1"
  spec.add_dependency "activerecord", ">= 4.0.0"

  spec.add_development_dependency "byebug", "~> 11.1" if debug
  spec.add_development_dependency "factory_bot", ">= 5"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.10"
  spec.add_development_dependency "rspec-block_is_expected", "~> 1.0"
  if linting
    spec.add_development_dependency("rubocop", "~> 1.22")
    spec.add_development_dependency("rubocop-faker", "~> 1.1")
    spec.add_development_dependency("rubocop-md", "~> 1.0")
    spec.add_development_dependency("rubocop-minitest", "~> 0.15")
    spec.add_development_dependency("rubocop-packaging", "~> 0.5")
    spec.add_development_dependency("rubocop-performance", "~> 1.11")
    spec.add_development_dependency("rubocop-rake", "~> 0.6")
    spec.add_development_dependency("rubocop-rspec", "~> 2.5")
    spec.add_development_dependency("rubocop-thread_safety", "~> 0.4")
  end
  if coverage
    spec.add_development_dependency("simplecov", "~> 0.21")
    spec.add_development_dependency("simplecov-cobertura", "~> 1.4")
  end
  spec.add_development_dependency "sqlite3", "~> 1"
  spec.add_development_dependency "yard", ">= 0.9.20"
end
