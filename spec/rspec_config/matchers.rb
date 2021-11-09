# frozen_string_literal: true

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.configure do |config|
  config.include RSpec::Benchmark::Matchers
end
