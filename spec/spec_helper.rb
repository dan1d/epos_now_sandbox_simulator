# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/db/migrate/"
    add_filter "/db/factories/"
    enable_coverage :branch
    minimum_coverage line: 100, branch: 100
  end
end

require "epos_now_sandbox_simulator"
require "webmock/rspec"
require "factory_bot"

# Disable real HTTP connections in tests
WebMock.disable_net_connect!

# Set test configuration
ENV["EPOS_NOW_API_KEY"] = "test_api_key"
ENV["EPOS_NOW_API_SECRET"] = "test_api_secret"
ENV["LOG_LEVEL"] = "ERROR"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.order = :random

  # FactoryBot
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    factories_path = File.expand_path("../lib/epos_now_sandbox_simulator/db/factories", __dir__)
    FactoryBot.definition_file_paths = [factories_path]
    FactoryBot.find_definitions
  end

  # Database setup for DB-dependent specs
  config.before(:each, :db) do
    url = EposNowSandboxSimulator::Database.test_database_url
    EposNowSandboxSimulator::Database.connect!(url)
  end

  config.after(:each, :db) do
    EposNowSandboxSimulator::Database.disconnect!
  end
end

# Helper to build auth header
def epos_now_auth_header
  require "base64"
  token = Base64.strict_encode64("test_api_key:test_api_secret")
  { "Authorization" => "Basic #{token}", "Content-Type" => "application/json", "Accept" => "application/json" }
end

# Helper for stubbing Epos Now V4 API
def stub_epos_now_api(method, path, response_body:, status: 200)
  stub_request(method, "https://api.eposnowhq.com/api/v4/#{path}")
    .to_return(
      status: status,
      body: response_body.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end
