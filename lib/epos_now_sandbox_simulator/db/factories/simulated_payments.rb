# frozen_string_literal: true

FactoryBot.define do
  factory :simulated_payment, class: "EposNowSandboxSimulator::Models::SimulatedPayment" do
    simulated_order
    sequence(:epos_now_tender_id) { |n| n + 20_000 }
    tender_name { "Credit Card" }
    amount { simulated_order&.total || rand(1000..5000) }
    tip_amount { 0 }
    tax_amount { 0 }
    status { "success" }
    payment_type { "credit_card" }
  end
end
