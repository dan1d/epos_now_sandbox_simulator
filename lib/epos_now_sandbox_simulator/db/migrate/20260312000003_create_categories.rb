# frozen_string_literal: true

class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories, id: :uuid do |t|
      t.string :name, null: false
      t.string :description
      t.integer :sort_order, null: false, default: 0
      t.references :business_type, type: :uuid, null: false, foreign_key: true

      t.timestamps

      t.index %i[business_type_id name], unique: true
    end
  end
end
