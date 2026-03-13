# frozen_string_literal: true

FactoryBot.define do
  factory :simulated_order, class: "EposNowSandboxSimulator::Models::SimulatedOrder" do
    sequence(:epos_now_transaction_id) { |n| n + 10_000 }
    status { "paid" }
    business_date { Date.today }
    dining_option { %w[walk_in take_away delivery].sample }
    meal_period { %w[breakfast lunch happy_hour dinner late_night].sample }
    subtotal { rand(1000..5000) }
    tax_amount { (subtotal * 0.0825).round }
    tip_amount { rand(0..500) }
    discount_amount { 0 }
    total { subtotal + tax_amount + tip_amount - discount_amount }
    metadata { {} }

    trait :refunded do
      status { "refunded" }
    end

    trait :open do
      status { "open" }
    end
  end
end
