# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Generators::DataLoader do
  describe "#load_categories" do
    it "loads restaurant categories from JSON" do
      loader = described_class.new(business_type: :restaurant)
      categories = loader.load_categories

      expect(categories).to be_an(Array)
      expect(categories.size).to eq(5)
      expect(categories.first["name"]).to eq("Appetizers")
    end

    it "loads cafe_bakery categories from JSON" do
      loader = described_class.new(business_type: :cafe_bakery)
      categories = loader.load_categories

      expect(categories.size).to eq(5)
      expect(categories.first["name"]).to eq("Hot Drinks")
    end

    it "loads bar_nightclub categories from JSON" do
      loader = described_class.new(business_type: :bar_nightclub)
      categories = loader.load_categories

      expect(categories.size).to eq(5)
    end

    it "loads retail_general categories from JSON" do
      loader = described_class.new(business_type: :retail_general)
      categories = loader.load_categories

      expect(categories.size).to eq(5)
    end

    it "loads from DB when connected" do
      loader = described_class.new(business_type: :restaurant)
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)

      bt_double = double("BusinessType")
      categories_relation = double("categories")
      allow(EposNowSandboxSimulator::Models::BusinessType).to receive(:find_by)
        .with(key: "restaurant").and_return(bt_double)
      allow(bt_double).to receive(:categories).and_return(categories_relation)
      allow(categories_relation).to receive(:order).with(:sort_order).and_return([
                                                                                   double("cat", name: "Appetizers", sort_order: 1,
                                                                                                 description: "Starters")
                                                                                 ])

      categories = loader.load_categories
      expect(categories.first["name"]).to eq("Appetizers")
      expect(categories.first["description"]).to eq("Starters")
    end

    it "falls back to JSON when business type not in DB" do
      loader = described_class.new(business_type: :restaurant)
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(EposNowSandboxSimulator::Models::BusinessType).to receive(:find_by)
        .with(key: "restaurant").and_return(nil)

      categories = loader.load_categories
      expect(categories.size).to eq(5)
    end
  end

  describe "#load_items" do
    it "loads restaurant items from JSON" do
      loader = described_class.new(business_type: :restaurant)
      items = loader.load_items

      expect(items).to be_an(Array)
      expect(items.size).to eq(25)
      expect(items.first).to include("name", "price", "category", "sku")
    end

    it "loads cafe_bakery items from JSON" do
      loader = described_class.new(business_type: :cafe_bakery)
      items = loader.load_items

      expect(items.size).to eq(24)
    end

    it "loads from DB when connected" do
      loader = described_class.new(business_type: :restaurant)
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)

      bt_double = double("BusinessType")
      items_relation = double("items")
      cat_double = double("category", name: "Appetizers")
      item_double = double("item", name: "Wings", price: 999, sku: "W001", category: cat_double)

      allow(EposNowSandboxSimulator::Models::BusinessType).to receive(:find_by)
        .with(key: "restaurant").and_return(bt_double)
      allow(bt_double).to receive(:items).and_return(items_relation)
      allow(items_relation).to receive(:includes).with(:category).and_return([item_double])

      items = loader.load_items
      expect(items.first["name"]).to eq("Wings")
      expect(items.first["price"]).to eq(9.99)
      expect(items.first["category"]).to eq("Appetizers")
    end

    it "handles item with nil category from DB" do
      loader = described_class.new(business_type: :restaurant)
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)

      bt_double = double("BusinessType")
      items_relation = double("items")
      item_double = double("item", name: "Orphan", price: 500, sku: nil, category: nil)

      allow(EposNowSandboxSimulator::Models::BusinessType).to receive(:find_by)
        .with(key: "restaurant").and_return(bt_double)
      allow(bt_double).to receive(:items).and_return(items_relation)
      allow(items_relation).to receive(:includes).with(:category).and_return([item_double])

      items = loader.load_items
      expect(items.first["category"]).to be_nil
    end

    it "falls back to JSON when business type not in DB" do
      loader = described_class.new(business_type: :restaurant)
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(EposNowSandboxSimulator::Models::BusinessType).to receive(:find_by)
        .with(key: "restaurant").and_return(nil)

      items = loader.load_items
      expect(items.size).to eq(25)
    end
  end

  describe "#load_tenders" do
    it "loads tender types from JSON" do
      loader = described_class.new(business_type: :restaurant)
      tenders = loader.load_tenders

      expect(tenders).to be_an(Array)
      expect(tenders.size).to eq(5)
      expect(tenders.first).to include("name", "weight")
    end
  end

  describe "#load_items_by_category" do
    it "groups items by category" do
      loader = described_class.new(business_type: :restaurant)
      grouped = loader.load_items_by_category

      expect(grouped).to be_a(Hash)
      expect(grouped.keys).to include("Appetizers", "Entrees", "Drinks")
      expect(grouped["Appetizers"].size).to eq(5)
    end
  end

  describe "missing business type" do
    it "returns empty array for unknown type" do
      loader = described_class.new(business_type: :nonexistent)
      expect(loader.load_categories).to eq([])
    end
  end

  describe "private #load_from_json" do
    it "returns empty hash for missing file" do
      loader = described_class.new(business_type: :nonexistent)
      result = loader.send(:load_from_json, "categories")
      expect(result).to eq({})
    end

    it "handles JSON parse errors" do
      loader = described_class.new(business_type: :restaurant)
      path = File.join(described_class::DATA_DIR, "restaurant", "categories.json")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(path).and_return(true)
      allow(File).to receive(:read).with(path).and_return("invalid json!")

      result = loader.send(:load_from_json, "categories")
      expect(result).to eq({})
    end
  end

  describe "BUSINESS_TYPES" do
    it "includes all four types" do
      expect(described_class::BUSINESS_TYPES).to contain_exactly(:restaurant, :cafe_bakery, :bar_nightclub, :retail_general)
    end
  end
end
