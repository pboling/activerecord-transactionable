require 'spec_helper'

describe Activerecord::Transactionable do
  it 'has a version number' do
    expect(Activerecord::Transactionable::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(false).to eq(true)
  end
end
