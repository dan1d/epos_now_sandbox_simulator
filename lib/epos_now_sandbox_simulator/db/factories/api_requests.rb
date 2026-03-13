# frozen_string_literal: true

FactoryBot.define do
  factory :api_request, class: "EposNowSandboxSimulator::Models::ApiRequest" do
    http_method { "GET" }
    url { "https://api.eposnowhq.com/api/V2/Category" }
    request_payload { {} }
    response_status { 200 }
    response_payload { {} }
    duration_ms { rand(50..500) }
    resource_type { "Category" }
  end
end
