# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Seeder do
  describe "SEED_MAP" do
    it "has 4 business types" do
      expect(described_class::SEED_MAP.keys).to contain_exactly(:restaurant, :cafe_bakery, :bar_nightclub, :retail_general)
    end

    it "each type has industry and categories" do
      described_class::SEED_MAP.each do |key, config|
        expect(config).to have_key(:industry), "#{key} missing :industry"
        expect(config).to have_key(:categories), "#{key} missing :categories"
        expect(config[:categories]).to be_a(Hash)
      end
    end

    it "restaurant has correct categories" do
      categories = described_class::SEED_MAP[:restaurant][:categories]
      expect(categories.keys).to contain_exactly(:appetizers, :entrees, :sides, :drinks, :desserts)
    end

    it "cafe_bakery has correct categories" do
      categories = described_class::SEED_MAP[:cafe_bakery][:categories]
      expect(categories.keys).to contain_exactly(:hot_drinks, :cold_drinks, :pastries, :sandwiches, :cakes)
    end

    it "bar_nightclub has correct categories" do
      categories = described_class::SEED_MAP[:bar_nightclub][:categories]
      expect(categories.keys).to contain_exactly(:draft_beer, :bottled_beer, :cocktails, :wine, :bar_snacks)
    end

    it "retail_general has correct categories" do
      categories = described_class::SEED_MAP[:retail_general][:categories]
      expect(categories.keys).to contain_exactly(:electronics, :clothing, :home_and_garden, :health_beauty, :groceries)
    end

    it "restaurant has 25 total items" do
      total = described_class::SEED_MAP[:restaurant][:categories].values.flatten.size
      expect(total).to eq(25)
    end

    it "cafe_bakery has 24 total items" do
      total = described_class::SEED_MAP[:cafe_bakery][:categories].values.flatten.size
      expect(total).to eq(24)
    end

    it "all types have Food or Retail industry" do
      described_class::SEED_MAP.each_value do |config|
        expect(config[:industry]).to be_in(%w[Food Retail])
      end
    end
  end

  describe ".seed!" do
    let(:bt_double) { double("BusinessType", id: "uuid-1") }
    let(:cat_double) { double("Category", id: "uuid-2") }
    let(:item_double) { double("Item", id: "uuid-3") }

    before do
      allow(EposNowSandboxSimulator::Models::BusinessType).to receive(:find_or_create_by!)
        .and_yield(bt_double).and_return(bt_double)
      allow(EposNowSandboxSimulator::Models::Category).to receive(:find_or_create_by!)
        .and_yield(cat_double).and_return(cat_double)
      allow(EposNowSandboxSimulator::Models::Item).to receive(:find_or_create_by!)
        .and_yield(item_double).and_return(item_double)
      allow(bt_double).to receive(:name=)
      allow(bt_double).to receive(:industry=)
      allow(cat_double).to receive(:sort_order=)
      allow(item_double).to receive(:category=)
      allow(item_double).to receive(:price=)
      allow(item_double).to receive(:sku=)
    end

    it "seeds a specific business type" do
      counts = described_class.seed!(business_type: :restaurant)
      expect(counts[:business_types]).to eq(1)
      expect(counts[:categories]).to eq(5)
      expect(counts[:items]).to eq(25)
    end

    it "seeds all business types when none specified" do
      counts = described_class.seed!
      expect(counts[:business_types]).to eq(4)
    end

    it "skips unknown business types" do
      counts = described_class.seed!(business_type: :nonexistent)
      expect(counts[:business_types]).to eq(0)
    end

    it "uses item price from JSON data" do
      described_class.seed!(business_type: :restaurant)
      expect(item_double).to have_received(:price=).at_least(:once)
    end
  end

  describe ".humanize_key" do
    it "converts snake_case to Title Case" do
      expect(described_class.send(:humanize_key, :hot_drinks)).to eq("Hot Drinks")
    end

    it "handles single word" do
      expect(described_class.send(:humanize_key, :appetizers)).to eq("Appetizers")
    end

    it "handles three words" do
      expect(described_class.send(:humanize_key, :home_and_garden)).to eq("Home And Garden")
    end
  end
end
