# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Services::EposNow::ServicesManager do
  let(:manager) { described_class.new }

  describe "#inventory" do
    it "returns an InventoryService" do
      expect(manager.inventory).to be_a(EposNowSandboxSimulator::Services::EposNow::InventoryService)
    end

    it "memoizes the instance" do
      expect(manager.inventory).to be(manager.inventory)
    end
  end

  describe "#tender" do
    it "returns a TenderService" do
      expect(manager.tender).to be_a(EposNowSandboxSimulator::Services::EposNow::TenderService)
    end

    it "memoizes the instance" do
      expect(manager.tender).to be(manager.tender)
    end
  end

  describe "#transaction" do
    it "returns a TransactionService" do
      expect(manager.transaction).to be_a(EposNowSandboxSimulator::Services::EposNow::TransactionService)
    end

    it "memoizes the instance" do
      expect(manager.transaction).to be(manager.transaction)
    end
  end

  describe "#tax" do
    it "returns a TaxService" do
      expect(manager.tax).to be_a(EposNowSandboxSimulator::Services::EposNow::TaxService)
    end

    it "memoizes the instance" do
      expect(manager.tax).to be(manager.tax)
    end
  end

  describe "thread safety" do
    it "handles concurrent access to the same service" do
      results = []
      threads = 3.times.map do
        Thread.new { results << manager.inventory }
      end
      threads.each(&:join)
      # All threads should get the same memoized instance
      expect(results.uniq.size).to eq(1)
    end
  end
end
