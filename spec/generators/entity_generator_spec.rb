# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Generators::EntityGenerator do
  let(:generator) { described_class.new(business_type: :restaurant) }
  let(:base_url) { "https://api.eposnowhq.com/api/v4" }

  before do
    # Stub category search (find_or_create)
    stub_request(:get, %r{#{base_url}/Category\?Name=})
      .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

    # Stub category creation
    stub_request(:post, "#{base_url}/Category")
      .to_return do |request|
        body = JSON.parse(request.body)
        { status: 201, body: { "Id" => rand(1..999), "Name" => body["Name"] }.to_json, headers: { "Content-Type" => "application/json" } }
      end

    # Stub product search
    stub_request(:get, %r{#{base_url}/Product\?Name=})
      .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

    # Stub product creation
    stub_request(:post, "#{base_url}/Product")
      .to_return do |request|
        body = JSON.parse(request.body)
        { status: 201, body: { "Id" => rand(1..999), "Name" => body["Name"], "SalePrice" => body["SalePrice"] }.to_json,
          headers: { "Content-Type" => "application/json" } }
      end

    # Stub tender type fetch (for find_or_create)
    stub_request(:get, "#{base_url}/TenderType?page=1")
      .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

    # Stub tender type creation
    stub_request(:post, "#{base_url}/TenderType")
      .to_return do |request|
        body = JSON.parse(request.body)
        { status: 201, body: { "Id" => rand(1..99), "Name" => body["Name"] }.to_json, headers: { "Content-Type" => "application/json" } }
      end
  end

  describe "#setup_all" do
    it "creates categories, products, and tender types" do
      stats = generator.setup_all

      expect(stats[:categories]).to eq(5)
      expect(stats[:products]).to eq(25)
      expect(stats[:tender_types]).to eq(5)
    end
  end

  describe "#setup_tender_types" do
    it "creates tender types from data" do
      types = generator.setup_tender_types
      expect(types.size).to eq(5)
    end
  end

  describe "#setup_categories" do
    it "creates all categories for business type" do
      categories = generator.setup_categories
      expect(categories.size).to eq(5)
      expect(categories.keys).to include("Appetizers", "Entrees")
    end
  end

  describe "#setup_products" do
    it "creates all products linked to categories" do
      categories = generator.setup_categories
      products = generator.setup_products(categories)
      expect(products.size).to eq(25)
    end
  end

  context "with cafe_bakery business type" do
    let(:generator) { described_class.new(business_type: :cafe_bakery) }

    it "creates cafe categories and products" do
      stats = generator.setup_all
      expect(stats[:categories]).to eq(5)
      expect(stats[:products]).to eq(24)
    end
  end

  context "with bar_nightclub business type" do
    let(:generator) { described_class.new(business_type: :bar_nightclub) }

    it "creates bar categories and products" do
      stats = generator.setup_all
      expect(stats[:categories]).to eq(5)
      expect(stats[:products]).to eq(22)
    end
  end

  context "with retail_general business type" do
    let(:generator) { described_class.new(business_type: :retail_general) }

    it "creates retail categories and products" do
      stats = generator.setup_all
      expect(stats[:categories]).to eq(5)
      expect(stats[:products]).to eq(13)
    end
  end

  describe "#setup_products with nil category" do
    it "passes nil category_id when category not found" do
      # Set up categories that won't match any item categories
      categories = { "NonexistentCategory" => { "Id" => 999 } }

      stub_request(:get, %r{#{base_url}/Product\?Name=})
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })
      stub_request(:post, "#{base_url}/Product")
        .to_return do |request|
          body = JSON.parse(request.body)
          { status: 201, body: { "Id" => rand(1..999), "Name" => body["Name"] }.to_json,
            headers: { "Content-Type" => "application/json" } }
        end

      products = generator.setup_products(categories)
      expect(products.size).to eq(25)
    end
  end
end
