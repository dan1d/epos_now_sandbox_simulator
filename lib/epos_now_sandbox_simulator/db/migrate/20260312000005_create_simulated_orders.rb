# frozen_string_literal: true

class CreateSimulatedOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :simulated_orders, id: :uuid do |t|
      t.integer :epos_now_transaction_id
      t.string :status, null: false, default: "open"
      t.date :business_date
      t.string :dining_option       # walk_in, take_away, delivery
      t.string :meal_period         # breakfast, lunch, happy_hour, dinner, late_night
      t.integer :subtotal, default: 0       # cents
      t.integer :tax_amount, default: 0     # cents
      t.integer :tip_amount, default: 0     # cents
      t.integer :discount_amount, default: 0 # cents
      t.integer :total, default: 0 # cents
      t.jsonb :metadata, default: {}

      t.timestamps

      t.index :epos_now_transaction_id, unique: true
      t.index :status
      t.index :business_date
      t.index :meal_period
      t.index :dining_option
    end
  end
end
