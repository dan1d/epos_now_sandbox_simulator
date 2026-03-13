# frozen_string_literal: true

FactoryBot.define do
  factory :item, class: "EposNowSandboxSimulator::Models::Item" do
    business_type
    category
    sequence(:name) { |n| "Item #{n}" }
    price { rand(299..2999) } # cents
    sequence(:sku) { |n| "SKU-#{n.to_s.rjust(5, "0")}" }
    metadata { {} }
  end
end
