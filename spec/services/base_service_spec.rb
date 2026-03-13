# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Services::BaseService do
  let(:service) { described_class.new }
  let(:base_url) { "https://api.eposnowhq.com/api/v4" }

  describe "#initialize" do
    it "uses default configuration" do
      expect(service.config).to be_a(EposNowSandboxSimulator::Configuration)
    end

    it "validates configuration" do
      config = EposNowSandboxSimulator::Configuration.new
      config.api_key = nil
      expect { described_class.new(config: config) }.to raise_error(EposNowSandboxSimulator::ConfigurationError)
    end
  end

  describe "API_PREFIX" do
    it "uses V4 prefix" do
      expect(described_class::API_PREFIX).to eq("api/v4")
    end
  end

  describe "#request" do
    it "makes GET requests with Basic Auth" do
      stub_request(:get, "#{base_url}/Category?page=1")
        .with(headers: { "Authorization" => /^Basic / })
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      result = service.send(:request, :get, "api/v4/Category", params: { page: 1 })
      expect(result).to eq([])
    end

    it "makes POST requests with JSON body" do
      stub_request(:post, "#{base_url}/Category")
        .to_return(status: 201, body: { "Id" => 1 }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.send(:request, :post, "api/v4/Category", payload: { "Name" => "Test" })
      expect(result["Id"]).to eq(1)
    end

    it "makes PUT requests" do
      stub_request(:put, "#{base_url}/Category/1")
        .to_return(status: 200, body: { "Id" => 1, "Name" => "Updated" }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.send(:request, :put, "api/v4/Category/1", payload: { "Name" => "Updated" })
      expect(result["Name"]).to eq("Updated")
    end

    it "makes DELETE requests" do
      stub_request(:delete, "#{base_url}/Category")
        .to_return(status: 204, body: "", headers: {})

      expect { service.send(:request, :delete, "api/v4/Category") }.not_to raise_error
    end

    it "makes DELETE requests with body (V4 style)" do
      stub_request(:delete, "#{base_url}/Category")
        .with(body: [{ "Id" => 5 }].to_json)
        .to_return(status: 204, body: "", headers: {})

      expect { service.send(:request, :delete, "api/v4/Category", payload: [{ "Id" => 5 }]) }.not_to raise_error
    end

    it "raises ApiError on HTTP error" do
      stub_request(:get, "#{base_url}/Category?page=1")
        .to_return(status: 401, body: { "message" => "Unauthorized" }.to_json, headers: { "Content-Type" => "application/json" })

      expect do
        service.send(:request, :get, "api/v4/Category", params: { page: 1 })
      end.to raise_error(EposNowSandboxSimulator::ApiError)
    end

    it "raises on unsupported HTTP method" do
      expect do
        service.send(:request, :patch, "api/v4/Category")
      end.to raise_error(EposNowSandboxSimulator::ApiError, /Unsupported HTTP method/)
    end

    it "passes resource_type and resource_id for audit" do
      stub_request(:get, "#{base_url}/Category/1")
        .to_return(status: 200, body: { "Id" => 1 }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.send(:request, :get, "api/v4/Category/1", resource_type: "Category", resource_id: "1")
      expect(result["Id"]).to eq(1)
    end

    it "audits API requests when DB connected" do
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(EposNowSandboxSimulator::Models::ApiRequest).to receive(:create!)

      stub_request(:get, "#{base_url}/Category?page=1")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      service.send(:request, :get, "api/v4/Category", params: { page: 1 })
      expect(EposNowSandboxSimulator::Models::ApiRequest).to have_received(:create!)
    end

    it "handles audit logging failure gracefully" do
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(EposNowSandboxSimulator::Models::ApiRequest).to receive(:create!).and_raise(StandardError, "db error")

      stub_request(:get, "#{base_url}/Category?page=1")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      expect { service.send(:request, :get, "api/v4/Category", params: { page: 1 }) }.not_to raise_error
    end

    it "makes POST request without payload" do
      stub_request(:post, "#{base_url}/Category")
        .to_return(status: 201, body: { "Id" => 1 }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.send(:request, :post, "api/v4/Category")
      expect(result["Id"]).to eq(1)
    end

    it "makes PUT request without payload" do
      stub_request(:put, "#{base_url}/Category/1")
        .to_return(status: 200, body: { "Id" => 1 }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.send(:request, :put, "api/v4/Category/1")
      expect(result["Id"]).to eq(1)
    end

    it "handles non-JSON error response body" do
      stub_request(:get, "#{base_url}/Category?page=1")
        .to_return(status: 500, body: "plain text error", headers: { "Content-Type" => "text/plain" })

      expect do
        service.send(:request, :get, "api/v4/Category", params: { page: 1 })
      end.to raise_error(EposNowSandboxSimulator::ApiError)
    end

    it "audits failed API requests when DB connected" do
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(EposNowSandboxSimulator::Models::ApiRequest).to receive(:create!)

      stub_request(:get, "#{base_url}/Category?page=1")
        .to_return(status: 500, body: { "message" => "Server Error" }.to_json, headers: { "Content-Type" => "application/json" })

      expect do
        service.send(:request, :get, "api/v4/Category", params: { page: 1 })
      end.to raise_error(EposNowSandboxSimulator::ApiError)
      expect(EposNowSandboxSimulator::Models::ApiRequest).to have_received(:create!)
    end
  end

  describe "#endpoint" do
    it "builds V4 API endpoint path" do
      expect(service.send(:endpoint, "Category")).to eq("api/v4/Category")
    end

    it "builds nested endpoint paths" do
      expect(service.send(:endpoint, "Transaction/GetByDate")).to eq("api/v4/Transaction/GetByDate")
    end
  end

  describe "#fetch_all_pages" do
    it "fetches multiple pages until empty" do
      page1 = (1..200).map { |i| { "Id" => i } }
      page2 = (201..210).map { |i| { "Id" => i } }

      stub_request(:get, "#{base_url}/Category?page=1")
        .to_return(status: 200, body: page1.to_json, headers: { "Content-Type" => "application/json" })
      stub_request(:get, "#{base_url}/Category?page=2")
        .to_return(status: 200, body: page2.to_json, headers: { "Content-Type" => "application/json" })

      result = service.send(:fetch_all_pages, "Category")
      expect(result.size).to eq(210)
    end

    it "stops at first empty page" do
      stub_request(:get, "#{base_url}/Product?page=1")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      result = service.send(:fetch_all_pages, "Product")
      expect(result).to eq([])
    end

    it "passes additional params" do
      stub_request(:get, "#{base_url}/Product?Name=Coffee&page=1")
        .to_return(status: 200, body: [{ "Id" => 1 }].to_json, headers: { "Content-Type" => "application/json" })

      result = service.send(:fetch_all_pages, "Product", params: { "Name" => "Coffee" })
      expect(result.size).to eq(1)
    end

    it "handles non-array response" do
      stub_request(:get, "#{base_url}/Product?page=1")
        .to_return(status: 200, body: { "error" => "bad" }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.send(:fetch_all_pages, "Product")
      expect(result).to eq([])
    end
  end

  describe "#with_api_fallback" do
    it "returns block result on success" do
      result = service.send(:with_api_fallback, fallback: "default") { "success" }
      expect(result).to eq("success")
    end

    it "returns fallback on ApiError" do
      result = service.send(:with_api_fallback, fallback: "default") do
        raise EposNowSandboxSimulator::ApiError, "failed"
      end
      expect(result).to eq("default")
    end

    it "returns fallback on StandardError" do
      result = service.send(:with_api_fallback, fallback: "default") do
        raise StandardError, "oops"
      end
      expect(result).to eq("default")
    end
  end

  describe "#safe_dig" do
    it "digs into nested hashes" do
      hash = { "a" => { "b" => "value" } }
      expect(service.send(:safe_dig, hash, "a", "b")).to eq("value")
    end

    it "returns default for missing keys" do
      expect(service.send(:safe_dig, {}, "a", "b", default: "fallback")).to eq("fallback")
    end

    it "returns default for nil hash" do
      expect(service.send(:safe_dig, nil, "a", default: "fallback")).to eq("fallback")
    end

    it "returns default when dig raises error" do
      bad_obj = Object.new
      expect(service.send(:safe_dig, bad_obj, "a", default: "fallback")).to eq("fallback")
    end
  end

  describe "private #build_url" do
    it "builds URL from relative path" do
      url = service.send(:build_url, "api/v4/Category")
      expect(url).to include("api.eposnowhq.com")
      expect(url).to include("api/v4/Category")
    end

    it "uses absolute URL when path starts with http" do
      url = service.send(:build_url, "https://custom.api.com/v4/Category")
      expect(url).to eq("https://custom.api.com/v4/Category")
    end

    it "appends query params" do
      url = service.send(:build_url, "api/v4/Category", { page: 1, status: 2 })
      expect(url).to include("page=1")
      expect(url).to include("status=2")
    end

    it "returns base URL when no params" do
      url = service.send(:build_url, "api/v4/Category", nil)
      expect(url).not_to include("?")
    end
  end

  describe "private #parse_response" do
    it "returns nil for nil body" do
      response = double("response", body: nil)
      expect(service.send(:parse_response, response)).to be_nil
    end

    it "returns nil for empty body" do
      response = double("response", body: "")
      expect(service.send(:parse_response, response)).to be_nil
    end

    it "parses valid JSON" do
      response = double("response", body: '{"Id":1}')
      expect(service.send(:parse_response, response)).to eq({ "Id" => 1 })
    end

    it "raises ApiError on invalid JSON" do
      response = double("response", body: "not json")
      expect { service.send(:parse_response, response) }.to raise_error(EposNowSandboxSimulator::ApiError, /Invalid JSON/)
    end
  end

  describe "private #handle_api_error" do
    it "parses error response body" do
      error_response = double("response", body: '{"message":"Not Found"}', code: 404)
      error = RestClient::ExceptionWithResponse.new(error_response)
      allow(error).to receive_messages(http_code: 404, response: error_response)

      expect { service.send(:handle_api_error, error) }.to raise_error(EposNowSandboxSimulator::ApiError, /404/)
    end

    it "handles unparseable error body" do
      error_response = double("response", body: "plain text error", code: 500)
      error = RestClient::ExceptionWithResponse.new(error_response)
      allow(error).to receive_messages(http_code: 500, response: error_response)

      expect { service.send(:handle_api_error, error) }.to raise_error(EposNowSandboxSimulator::ApiError, /500/)
    end
  end
end
