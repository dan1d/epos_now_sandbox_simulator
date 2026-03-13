# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator do
  describe "VERSION" do
    it "has a version string" do
      expect(described_class::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(EposNowSandboxSimulator::Configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      described_class.configure do |config|
        expect(config).to be_a(EposNowSandboxSimulator::Configuration)
      end
    end

    it "allows setting configuration values" do
      described_class.configure do |config|
        config.tax_rate = 10.0
      end
      expect(described_class.configuration.tax_rate).to eq(10.0)
      # Reset
      described_class.configuration.tax_rate = 8.25
    end
  end

  describe ".logger" do
    it "returns a Logger" do
      expect(described_class.logger).to be_a(Logger)
    end
  end

  describe ".root" do
    it "returns the gem root directory" do
      expect(described_class.root).to include("epos_now_sandbox_simulator")
    end
  end

  describe "Error classes" do
    it "defines Error as StandardError subclass" do
      expect(EposNowSandboxSimulator::Error.new).to be_a(StandardError)
    end

    it "defines ConfigurationError as Error subclass" do
      expect(EposNowSandboxSimulator::ConfigurationError.new).to be_a(EposNowSandboxSimulator::Error)
    end

    it "defines ApiError as Error subclass" do
      expect(EposNowSandboxSimulator::ApiError.new).to be_a(EposNowSandboxSimulator::Error)
    end
  end
end
