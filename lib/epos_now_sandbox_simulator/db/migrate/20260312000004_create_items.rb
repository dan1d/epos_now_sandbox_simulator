# frozen_string_literal: true

class CreateItems < ActiveRecord::Migration[8.0]
  def change
    create_table :items, id: :uuid do |t|
      t.string :name, null: false
      t.integer :price, null: false # price in cents
      t.string :sku
      t.string :barcode
      t.jsonb :metadata, default: {}
      t.references :business_type, type: :uuid, null: false, foreign_key: true
      t.references :category, type: :uuid, foreign_key: true

      t.timestamps

      t.index :sku, unique: true
    end
  end
end
