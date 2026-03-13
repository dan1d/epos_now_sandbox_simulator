# frozen_string_literal: true

FactoryBot.define do
  factory :business_type, class: "EposNowSandboxSimulator::Models::BusinessType" do
    sequence(:key) { |n| "business_type_#{n}" }
    name { key.tr("_", " ").split.map(&:capitalize).join(" ") }
    industry { "Food" }
    order_profile { {} }

    trait :restaurant do
      key { "restaurant" }
      name { "Restaurant" }
      industry { "Food" }
    end

    trait :cafe_bakery do
      key { "cafe_bakery" }
      name { "Cafe Bakery" }
      industry { "Food" }
    end

    trait :bar_nightclub do
      key { "bar_nightclub" }
      name { "Bar Nightclub" }
      industry { "Food" }
    end

    trait :retail_general do
      key { "retail_general" }
      name { "Retail General" }
      industry { "Retail" }
    end
  end
end
