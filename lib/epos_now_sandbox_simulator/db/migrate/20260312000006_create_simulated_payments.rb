# frozen_string_literal: true

class CreateSimulatedPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :simulated_payments, id: :uuid do |t|
      t.references :simulated_order, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.integer :epos_now_tender_id
      t.string :tender_name, null: false
      t.integer :amount, null: false, default: 0     # cents
      t.integer :tip_amount, default: 0              # cents
      t.integer :tax_amount, default: 0              # cents
      t.string :status, null: false, default: "pending"
      t.string :payment_type

      t.timestamps

      t.index :epos_now_tender_id, unique: true
      t.index :tender_name
      t.index :status
    end
  end
end
