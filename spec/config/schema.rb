# frozen_string_literal: true

ActiveRecord::Schema.define(version: 0) do
  create_table :plain_vanilla_ice_creams, force: true do |t|
    t.integer :kcal, null: false
  end
end
