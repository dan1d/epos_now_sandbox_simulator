# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Services::EposNow::InventoryService do
  let(:service) { described_class.new }
  let(:base_url) { "https://api.eposnowhq.com/api/v4" }

  describe "#fetch_categories" do
    it "fetches all categories across pages" do
      page1 = (1..200).map { |i| { "Id" => i, "Name" => "Cat #{i}" } }
      page2 = [{ "Id" => 201, "Name" => "Cat 201" }]

      stub_request(:get, "#{base_url}/Category?page=1")
        .to_return(status: 200, body: page1.to_json, headers: { "Content-Type" => "application/json" })
      stub_request(:get, "#{base_url}/Category?page=2")
        .to_return(status: 200, body: page2.to_json, headers: { "Content-Type" => "application/json" })

      categories = service.fetch_categories
      expect(categories.size).to eq(201)
    end

    it "returns empty array when no categories" do
      stub_request(:get, "#{base_url}/Category?page=1")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      expect(service.fetch_categories).to eq([])
    end
  end

  describe "#create_category" do
    it "creates a category via POST" do
      response = { "Id" => 1, "Name" => "Drinks", "ShowOnTill" => true }

      stub_request(:post, "#{base_url}/Category")
        .with(body: hash_including("Name" => "Drinks"))
        .to_return(status: 201, body: response.to_json, headers: { "Content-Type" => "application/json" })

      result = service.create_category(name: "Drinks")
      expect(result["Id"]).to eq(1)
      expect(result["Name"]).to eq("Drinks")
    end

    it "includes optional fields when provided" do
      stub_request(:post, "#{base_url}/Category")
        .with(body: hash_including("Name" => "Food", "Description" => "Main food", "SortPosition" => 2, "NominalCode" => "4000"))
        .to_return(status: 201, body: { "Id" => 2, "Name" => "Food" }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.create_category(name: "Food", description: "Main food", sort_position: 2, nominal_code: "4000")
      expect(result["Id"]).to eq(2)
    end
  end

  describe "#create_product" do
    it "creates a product via POST" do
      response = { "Id" => 1, "Name" => "Coffee", "SalePrice" => 4.50 }

      stub_request(:post, "#{base_url}/Product")
        .with(body: hash_including("Name" => "Coffee", "SalePrice" => 4.50))
        .to_return(status: 201, body: response.to_json, headers: { "Content-Type" => "application/json" })

      result = service.create_product(name: "Coffee", sale_price: 4.50)
      expect(result["Id"]).to eq(1)
    end

    it "sets EatOutPrice to sale_price by default" do
      stub_request(:post, "#{base_url}/Product")
        .with(body: hash_including("SalePrice" => 5.00, "EatOutPrice" => 5.00))
        .to_return(status: 201, body: { "Id" => 1, "Name" => "Tea" }.to_json, headers: { "Content-Type" => "application/json" })

      service.create_product(name: "Tea", sale_price: 5.00)
    end

    it "uses custom eat_out_price when provided" do
      stub_request(:post, "#{base_url}/Product")
        .with(body: hash_including("SalePrice" => 5.00, "EatOutPrice" => 5.50))
        .to_return(status: 201, body: { "Id" => 1, "Name" => "Latte" }.to_json, headers: { "Content-Type" => "application/json" })

      service.create_product(name: "Latte", sale_price: 5.00, eat_out_price: 5.50)
    end
  end

  describe "#fetch_products" do
    it "fetches all products" do
      products = [{ "Id" => 1, "Name" => "Item 1", "SalePrice" => 9.99 }]

      stub_request(:get, "#{base_url}/Product?page=1")
        .to_return(status: 200, body: products.to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_products
      expect(result.size).to eq(1)
    end
  end

  describe "#get_product" do
    it "fetches a single product by ID" do
      product = { "Id" => 42, "Name" => "Special Item", "SalePrice" => 15.99 }

      stub_request(:get, "#{base_url}/Product/42")
        .to_return(status: 200, body: product.to_json, headers: { "Content-Type" => "application/json" })

      result = service.get_product(42)
      expect(result["Name"]).to eq("Special Item")
    end
  end

  describe "#find_or_create_category" do
    it "returns existing category if found by name" do
      existing = [{ "Id" => 5, "Name" => "Drinks" }, { "Id" => 6, "Name" => "DrinksMix" }]

      stub_request(:get, "#{base_url}/Category?Name=Drinks")
        .to_return(status: 200, body: existing.to_json, headers: { "Content-Type" => "application/json" })

      result = service.find_or_create_category(name: "Drinks")
      expect(result["Id"]).to eq(5)
    end

    it "creates category when not found" do
      stub_request(:get, "#{base_url}/Category?Name=NewCat")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:post, "#{base_url}/Category")
        .to_return(status: 201, body: { "Id" => 10, "Name" => "NewCat" }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.find_or_create_category(name: "NewCat")
      expect(result["Id"]).to eq(10)
    end
  end

  describe "#find_or_create_product" do
    it "returns existing product if found" do
      existing = [{ "Id" => 7, "Name" => "Coffee", "SalePrice" => 4.50 }]

      stub_request(:get, "#{base_url}/Product?Name=Coffee")
        .to_return(status: 200, body: existing.to_json, headers: { "Content-Type" => "application/json" })

      result = service.find_or_create_product(name: "Coffee", sale_price: 4.50)
      expect(result["Id"]).to eq(7)
    end

    it "creates product when not found" do
      stub_request(:get, "#{base_url}/Product?Name=Muffin")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:post, "#{base_url}/Product")
        .to_return(status: 201, body: { "Id" => 20, "Name" => "Muffin",
                                        "SalePrice" => 3.99 }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.find_or_create_product(name: "Muffin", sale_price: 3.99)
      expect(result["Id"]).to eq(20)
    end
  end

  describe "#delete_category" do
    it "sends DELETE with request body" do
      stub_request(:delete, "#{base_url}/Category")
        .with(body: [{ "Id" => 5 }].to_json)
        .to_return(status: 204, body: "", headers: {})

      expect { service.delete_category(5) }.not_to raise_error
    end
  end

  describe "#delete_product" do
    it "sends DELETE with request body" do
      stub_request(:delete, "#{base_url}/Product")
        .with(body: [{ "Id" => 10 }].to_json)
        .to_return(status: 204, body: "", headers: {})

      expect { service.delete_product(10) }.not_to raise_error
    end
  end

  describe "#find_category_by_name" do
    it "returns nil when API returns non-array" do
      stub_request(:get, "#{base_url}/Category?Name=Test")
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      result = service.find_category_by_name("Test")
      expect(result).to be_nil
    end

    it "handles categories with nil Name" do
      stub_request(:get, "#{base_url}/Category?Name=Test")
        .to_return(status: 200, body: [{ "Id" => 1, "Name" => nil }].to_json, headers: { "Content-Type" => "application/json" })

      result = service.find_category_by_name("Test")
      expect(result).to be_nil
    end
  end

  describe "#find_product_by_name" do
    it "returns nil when API returns non-array" do
      stub_request(:get, "#{base_url}/Product?Name=Test")
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      result = service.find_product_by_name("Test")
      expect(result).to be_nil
    end

    it "handles products with nil Name" do
      stub_request(:get, "#{base_url}/Product?Name=Test")
        .to_return(status: 200, body: [{ "Id" => 1, "Name" => nil }].to_json, headers: { "Content-Type" => "application/json" })

      result = service.find_product_by_name("Test")
      expect(result).to be_nil
    end
  end

  describe "#create_category with parent_id" do
    it "includes ParentId when provided" do
      stub_request(:post, "#{base_url}/Category")
        .with(body: hash_including("ParentId" => 5))
        .to_return(status: 201, body: { "Id" => 3, "Name" => "SubCat" }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.create_category(name: "SubCat", parent_id: 5)
      expect(result["Id"]).to eq(3)
    end
  end

  describe "#create_product with optional fields" do
    it "includes barcode, sku, and description" do
      stub_request(:post, "#{base_url}/Product")
        .with(body: hash_including("Barcode" => "123", "Sku" => "SKU1", "Description" => "Desc"))
        .to_return(status: 201, body: { "Id" => 5, "Name" => "Item" }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.create_product(name: "Item", sale_price: 10.0, barcode: "123", sku: "SKU1", description: "Desc")
      expect(result["Id"]).to eq(5)
    end
  end
end
