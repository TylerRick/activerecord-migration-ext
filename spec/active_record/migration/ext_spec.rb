# frozen_string_literal: true

RSpec.describe ActiveRecord::Migration::Ext do
  it 'has a version number' do
    expect(ActiveRecord::Migration::Ext.version).not_to be nil
  end

  xit 'has sufficient tests' do
    expect(false).to eq(true)
  end
end
