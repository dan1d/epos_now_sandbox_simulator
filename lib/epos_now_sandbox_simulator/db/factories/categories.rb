# frozen_string_literal: true

FactoryBot.define do
  factory :category, class: "EposNowSandboxSimulator::Models::Category" do
    business_type
    sequence(:name) { |n| "Category #{n}" }
    sort_order { 1 }
    description { "A test category" }
  end
end
