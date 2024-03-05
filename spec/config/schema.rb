# frozen_string_literal: true

require "active_model"
require "active_record"

ActiveRecord::Schema[7.1].define(version: 0) do
  create_table :authors do |t|
    t.string :name, null: false
  end

  add_index :authors, :name, unique: true

  create_table :posts do |t|
    t.integer :author_id, null: false
    t.string :subject
    t.text :body
    t.boolean :private, default: false
  end

  add_index :posts, :author_id

  create_table :plain_vanilla_ice_creams do |t|
    t.integer :kcal, null: false
  end
end
