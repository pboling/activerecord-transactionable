# frozen_string_literal: true

RSpec.configure do |conf|
  conf.include SilentStream if defined?(SilentStream)
end
