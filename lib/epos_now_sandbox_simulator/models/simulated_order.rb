# frozen_string_literal: true

module EposNowSandboxSimulator
  module Models
    class SimulatedOrder < ActiveRecord::Base
      self.table_name = "simulated_orders"

      has_many :simulated_payments, class_name: "EposNowSandboxSimulator::Models::SimulatedPayment", dependent: :destroy

      validates :epos_now_transaction_id, presence: true
      validates :status, presence: true, inclusion: { in: %w[open paid refunded] }
      validates :dining_option, inclusion: { in: %w[walk_in take_away delivery], allow_nil: true }
      validates :meal_period, inclusion: { in: %w[breakfast lunch happy_hour dinner late_night], allow_nil: true }

      scope :paid, -> { where(status: "paid") }
      scope :refunded, -> { where(status: "refunded") }
      scope :for_date, ->(date) { where(business_date: date) }
      scope :for_meal_period, ->(period) { where(meal_period: period) }
    end
  end
end
