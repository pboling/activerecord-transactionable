lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activerecord/transactionable/version'

Gem::Specification.new do |spec|
  spec.name          = 'activerecord-transactionable'
  spec.version       = Activerecord::Transactionable::VERSION
  spec.authors       = ['Peter Boling']
  spec.email         = ['peter.boling@gmail.com']
  spec.licenses      = ['MIT']

  spec.summary       = 'Do ActiveRecord transactions the right way.'
  spec.description   = 'Getting transactions right is hard, and this gem makes it easier.'
  spec.homepage      = 'http://www.railsbling.com/tags/activerecord-transactionable'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.1.0' # Uses named required parameters

  spec.add_dependency 'activemodel'
  spec.add_dependency 'activerecord'

  spec.add_development_dependency 'appraisal', '~> 2.2'
  spec.add_development_dependency 'bundler', '~> 1.15'
  spec.add_development_dependency 'coveralls', '~> 0.8'
  spec.add_development_dependency 'rake', '~> 12.2'
  spec.add_development_dependency 'rspec', '~> 3.4'
  spec.add_development_dependency 'thor', '~> 0.19.1'
  spec.add_development_dependency 'wwtd', '~> 1.3'
end
