# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Services::EposNow::TenderService do
  let(:service) { described_class.new }
  let(:base_url) { "https://api.eposnowhq.com/api/v4" }

  describe "#fetch_tender_types" do
    it "fetches all tender types" do
      types = [
        { "Id" => 1, "Name" => "Cash" },
        { "Id" => 2, "Name" => "Credit Card" }
      ]

      stub_request(:get, "#{base_url}/TenderType?page=1")
        .to_return(status: 200, body: types.to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_tender_types
      expect(result.size).to eq(2)
      expect(result.first["Name"]).to eq("Cash")
    end

    it "paginates through multiple pages" do
      page1 = (1..200).map { |i| { "Id" => i, "Name" => "Type #{i}" } }
      page2 = [{ "Id" => 201, "Name" => "Type 201" }]

      stub_request(:get, "#{base_url}/TenderType?page=1")
        .to_return(status: 200, body: page1.to_json, headers: { "Content-Type" => "application/json" })
      stub_request(:get, "#{base_url}/TenderType?page=2")
        .to_return(status: 200, body: page2.to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_tender_types
      expect(result.size).to eq(201)
    end
  end

  describe "#get_tender_type" do
    it "fetches a single tender type by ID" do
      stub_request(:get, "#{base_url}/TenderType/1")
        .to_return(status: 200, body: { "Id" => 1, "Name" => "Cash" }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.get_tender_type(1)
      expect(result["Name"]).to eq("Cash")
    end
  end

  describe "#create_tender_type" do
    it "creates a tender type" do
      response = { "Id" => 3, "Name" => "Gift Card" }

      stub_request(:post, "#{base_url}/TenderType")
        .with(body: hash_including("Name" => "Gift Card"))
        .to_return(status: 201, body: response.to_json, headers: { "Content-Type" => "application/json" })

      result = service.create_tender_type(name: "Gift Card")
      expect(result["Id"]).to eq(3)
    end

    it "includes description when provided" do
      stub_request(:post, "#{base_url}/TenderType")
        .with(body: hash_including("Name" => "Check", "Description" => "Check payment"))
        .to_return(status: 201, body: { "Id" => 4, "Name" => "Check" }.to_json, headers: { "Content-Type" => "application/json" })

      service.create_tender_type(name: "Check", description: "Check payment")
    end
  end

  describe "#find_or_create_tender_type" do
    it "returns existing when found" do
      stub_request(:get, "#{base_url}/TenderType?page=1")
        .to_return(status: 200, body: [{ "Id" => 1, "Name" => "Cash" }].to_json, headers: { "Content-Type" => "application/json" })

      result = service.find_or_create_tender_type(name: "Cash")
      expect(result["Id"]).to eq(1)
    end

    it "creates when not found" do
      stub_request(:get, "#{base_url}/TenderType?page=1")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:post, "#{base_url}/TenderType")
        .to_return(status: 201, body: { "Id" => 5, "Name" => "New Type" }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.find_or_create_tender_type(name: "New Type")
      expect(result["Id"]).to eq(5)
    end
  end

  describe "#find_tender_type_by_name" do
    it "handles tender types with nil Name" do
      stub_request(:get, "#{base_url}/TenderType?page=1")
        .to_return(status: 200, body: [{ "Id" => 1, "Name" => nil }].to_json, headers: { "Content-Type" => "application/json" })

      result = service.find_tender_type_by_name("Cash")
      expect(result).to be_nil
    end
  end

  describe "#setup_default_tender_types" do
    before do
      stub_request(:get, "#{base_url}/TenderType?page=1")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:post, "#{base_url}/TenderType")
        .to_return do |request|
          body = JSON.parse(request.body)
          { status: 201, body: { "Id" => rand(1..99), "Name" => body["Name"] }.to_json, headers: { "Content-Type" => "application/json" } }
        end
    end

    it "creates all 5 default tender types" do
      result = service.setup_default_tender_types
      expect(result.size).to eq(5)
    end
  end
end
