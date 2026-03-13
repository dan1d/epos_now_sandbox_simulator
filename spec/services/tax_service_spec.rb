# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Services::EposNow::TaxService do
  let(:service) { described_class.new }
  let(:base_url) { "https://api.eposnowhq.com/api/v4" }

  describe "#calculate_tax" do
    it "calculates tax at default rate (8.25%)" do
      expect(service.calculate_tax(100.0)).to eq(8.25)
    end

    it "calculates tax at custom rate" do
      expect(service.calculate_tax(100.0, rate: 10.0)).to eq(10.0)
    end

    it "rounds to 2 decimal places" do
      expect(service.calculate_tax(33.33)).to eq(2.75)
    end

    it "handles zero amount" do
      expect(service.calculate_tax(0.0)).to eq(0.0)
    end

    it "handles large amounts" do
      expect(service.calculate_tax(9999.99)).to eq(825.0)
    end
  end

  describe "#fetch_tax_groups" do
    it "fetches all tax groups" do
      groups = [
        { "Id" => 1, "Name" => "Standard", "TaxRates" => [{ "Percentage" => 8.25 }] },
        { "Id" => 2, "Name" => "Reduced", "TaxRates" => [{ "Percentage" => 5.0 }] }
      ]

      stub_request(:get, "#{base_url}/TaxGroup?page=1")
        .to_return(status: 200, body: groups.to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_tax_groups
      expect(result.size).to eq(2)
      expect(result.first["TaxRates"].first["Percentage"]).to eq(8.25)
    end
  end

  describe "#get_tax_group" do
    it "fetches a single tax group with rates" do
      group = { "Id" => 1, "Name" => "Standard", "TaxRates" => [{ "Percentage" => 8.25, "Name" => "Sales Tax" }] }

      stub_request(:get, "#{base_url}/TaxGroup/1")
        .to_return(status: 200, body: group.to_json, headers: { "Content-Type" => "application/json" })

      result = service.get_tax_group(1)
      expect(result["Name"]).to eq("Standard")
    end
  end
end
