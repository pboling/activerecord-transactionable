# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activerecord/transactionable/version'

Gem::Specification.new do |spec|
  spec.name          = "activerecord-transactionable"
  spec.version       = Activerecord::Transactionable::VERSION
  spec.authors       = ["Peter Boling"]
  spec.email         = ["peter.boling@gmail.com"]
  spec.licenses       = ["MIT"]

  spec.summary       = %q{Do ActiveRecord transactions the right way.}
  spec.description   = %q{Getting transactions right is hard, and this gem makes it easier.}
  spec.homepage      = "http://www.railsbling.com/tags/activerecord-transactionable"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activemodel"
  spec.add_dependency "activerecord"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.4"
end
