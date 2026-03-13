# frozen_string_literal: true

module EposNowSandboxSimulator
  module Models
    class SimulatedPayment < ActiveRecord::Base
      self.table_name = "simulated_payments"

      belongs_to :simulated_order, class_name: "EposNowSandboxSimulator::Models::SimulatedOrder"

      validates :tender_name, presence: true
      validates :amount, presence: true
      validates :status, presence: true, inclusion: { in: %w[pending success failed] }

      scope :successful, -> { where(status: "success") }
    end
  end
end
