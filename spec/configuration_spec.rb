# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "loads api_key from ENV" do
      expect(config.api_key).to eq("test_api_key")
    end

    it "loads api_secret from ENV" do
      expect(config.api_secret).to eq("test_api_secret")
    end

    it "defaults environment to Epos Now API URL" do
      expect(config.environment).to include("api.eposnowhq.com")
    end

    it "defaults business_type to restaurant" do
      expect(config.business_type).to eq(:restaurant)
    end

    it "defaults tax_rate to 8.25" do
      expect(config.tax_rate).to eq(8.25)
    end

    it "defaults merchant_timezone to America/Los_Angeles" do
      expect(config.merchant_timezone).to eq("America/Los_Angeles")
    end

    it "normalizes environment URL with trailing slash" do
      expect(config.environment).to end_with("/")
    end

    it "handles empty merchants file when api_key not in ENV" do
      original_key = ENV.fetch("EPOS_NOW_API_KEY", nil)
      ENV["EPOS_NOW_API_KEY"] = ""
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(described_class::MERCHANTS_FILE).and_return(false)

      new_config = described_class.new
      expect(new_config.api_key).to eq("")
    ensure
      ENV["EPOS_NOW_API_KEY"] = original_key
    end

    it "loads from merchants file when api_key not in ENV" do
      original_key = ENV.fetch("EPOS_NOW_API_KEY", nil)
      ENV["EPOS_NOW_API_KEY"] = ""
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(described_class::MERCHANTS_FILE).and_return(true)
      allow(File).to receive(:read).with(described_class::MERCHANTS_FILE).and_return(
        [{ "EPOS_NOW_API_KEY" => "file_key", "EPOS_NOW_API_SECRET" => "file_secret", "EPOS_NOW_DEVICE_NAME" => "Dev1" }].to_json
      )

      new_config = described_class.new
      expect(new_config.api_key).to eq("file_key")
      expect(new_config.api_secret).to eq("file_secret")
      expect(new_config.device_name).to eq("Dev1")
    ensure
      ENV["EPOS_NOW_API_KEY"] = original_key
    end
  end

  describe "#auth_token" do
    it "returns Base64 encoded api_key:api_secret" do
      require "base64"
      expected = Base64.strict_encode64("test_api_key:test_api_secret")
      expect(config.auth_token).to eq(expected)
    end
  end

  describe "#validate!" do
    it "raises when api_key is missing" do
      config.api_key = nil
      expect { config.validate! }.to raise_error(EposNowSandboxSimulator::ConfigurationError, /API_KEY/)
    end

    it "raises when api_key is empty string" do
      config.api_key = ""
      expect { config.validate! }.to raise_error(EposNowSandboxSimulator::ConfigurationError, /API_KEY/)
    end

    it "raises when api_secret is missing" do
      config.api_secret = nil
      expect { config.validate! }.to raise_error(EposNowSandboxSimulator::ConfigurationError, /API_SECRET/)
    end

    it "raises when api_secret is empty string" do
      config.api_secret = ""
      expect { config.validate! }.to raise_error(EposNowSandboxSimulator::ConfigurationError, /API_SECRET/)
    end

    it "returns true when valid" do
      expect(config.validate!).to be true
    end
  end

  describe "#logger" do
    it "returns a Logger instance" do
      expect(config.logger).to be_a(Logger)
    end

    it "memoizes the logger" do
      expect(config.logger).to be(config.logger)
    end

    it "formats log messages with timestamp and severity" do
      output = StringIO.new
      new_config = described_class.new
      new_config.instance_variable_set(:@logger, nil)
      new_config.instance_variable_set(:@log_level, Logger::INFO)
      logger = Logger.new(output)
      logger.formatter = proc do |severity, datetime, _progname, msg|
        timestamp = datetime.strftime("%Y-%m-%d %H:%M:%S")
        "[#{timestamp}] #{severity.ljust(5)} | #{msg}\n"
      end
      new_config.instance_variable_set(:@logger, logger)
      new_config.logger.info("test message")
      expect(output.string).to match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] INFO  \| test message/)
    end
  end

  describe "#merchant_time_now" do
    it "returns current time in merchant timezone" do
      time = config.merchant_time_now
      expect(time).to be_a(Time)
    end

    it "uses TZInfo for timezone conversion" do
      config.merchant_timezone = "America/New_York"
      time = config.merchant_time_now
      expect(time).to be_a(Time)
    end

    it "falls back to ENV TZ when TZInfo is not available" do
      allow(config).to receive(:require).with("time")
      allow(config).to receive(:require).with("tzinfo").and_raise(LoadError)
      time = config.merchant_time_now
      expect(time).to be_a(Time)
    end
  end

  describe "#merchant_date_today" do
    it "returns a Date" do
      expect(config.merchant_date_today).to be_a(Date)
    end
  end

  describe "#load_merchant" do
    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(described_class::MERCHANTS_FILE).and_return(true)
      allow(File).to receive(:read).with(described_class::MERCHANTS_FILE).and_return(merchants_json)
    end

    let(:merchants_json) do
      {
        "merchants" => [
          { "EPOS_NOW_API_KEY" => "key1", "EPOS_NOW_API_SECRET" => "secret1", "EPOS_NOW_DEVICE_NAME" => "Device A" },
          { "EPOS_NOW_API_KEY" => "key2", "EPOS_NOW_API_SECRET" => "secret2", "EPOS_NOW_DEVICE_NAME" => "Device B" }
        ]
      }.to_json
    end

    it "loads merchant by device_name" do
      config.load_merchant(device_name: "Device B")
      expect(config.api_key).to eq("key2")
      expect(config.device_name).to eq("Device B")
    end

    it "loads merchant by index" do
      config.load_merchant(index: 1)
      expect(config.api_key).to eq("key2")
    end

    it "loads first merchant by default" do
      config.load_merchant
      expect(config.api_key).to eq("key1")
    end

    it "returns self" do
      expect(config.load_merchant).to be(config)
    end

    it "warns when device not found by name" do
      config.load_merchant(device_name: "nonexistent")
      expect(config.api_key).to eq("test_api_key")
    end

    it "warns when device not found by index" do
      config.load_merchant(index: 99)
      expect(config.api_key).to eq("test_api_key")
    end

    it "returns self when merchants file is empty" do
      allow(File).to receive(:exist?).with(described_class::MERCHANTS_FILE).and_return(false)
      expect(config.load_merchant).to be(config)
    end

    it "does not overwrite credentials with empty values" do
      merchants = [{ "EPOS_NOW_API_KEY" => "", "EPOS_NOW_API_SECRET" => "", "EPOS_NOW_DEVICE_NAME" => "" }].to_json
      allow(File).to receive(:read).with(described_class::MERCHANTS_FILE).and_return(merchants)
      config.load_merchant
      expect(config.api_key).to eq("test_api_key")
    end
  end

  describe "#available_merchants" do
    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(described_class::MERCHANTS_FILE).and_return(true)
    end

    it "returns array of device info" do
      allow(File).to receive(:read).with(described_class::MERCHANTS_FILE).and_return(
        [{ "EPOS_NOW_API_KEY" => "k", "EPOS_NOW_API_SECRET" => "s", "EPOS_NOW_DEVICE_NAME" => "Dev" }].to_json
      )
      merchants = config.available_merchants
      expect(merchants).to eq([{ name: "Dev", has_credentials: true }])
    end

    it "detects missing credentials" do
      allow(File).to receive(:read).with(described_class::MERCHANTS_FILE).and_return(
        [{ "EPOS_NOW_DEVICE_NAME" => "Empty" }].to_json
      )
      merchants = config.available_merchants
      expect(merchants.first[:has_credentials]).to be false
    end
  end

  describe ".database_url_from_file" do
    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(described_class::MERCHANTS_FILE).and_return(true)
    end

    it "returns DATABASE_URL from object-format JSON" do
      allow(File).to receive(:read).with(described_class::MERCHANTS_FILE).and_return(
        { "DATABASE_URL" => "postgres://localhost/testdb", "merchants" => [] }.to_json
      )
      expect(described_class.database_url_from_file).to eq("postgres://localhost/testdb")
    end

    it "returns nil for array-format JSON" do
      allow(File).to receive(:read).with(described_class::MERCHANTS_FILE).and_return([].to_json)
      expect(described_class.database_url_from_file).to be_nil
    end

    it "returns nil when file does not exist" do
      allow(File).to receive(:exist?).with(described_class::MERCHANTS_FILE).and_return(false)
      expect(described_class.database_url_from_file).to be_nil
    end

    it "returns nil on JSON parse error" do
      allow(File).to receive(:read).with(described_class::MERCHANTS_FILE).and_return("not json")
      expect(described_class.database_url_from_file).to be_nil
    end
  end

  describe "private #load_merchants_file" do
    it "returns empty array when file does not exist" do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(described_class::MERCHANTS_FILE).and_return(false)
      expect(config.send(:load_merchants_file)).to eq([])
    end

    it "parses array-format JSON" do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(described_class::MERCHANTS_FILE).and_return(true)
      allow(File).to receive(:read).with(described_class::MERCHANTS_FILE).and_return(
        [{ "EPOS_NOW_API_KEY" => "k1" }].to_json
      )
      result = config.send(:load_merchants_file)
      expect(result).to be_an(Array)
      expect(result.size).to eq(1)
    end

    it "parses object-format JSON with merchants key" do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(described_class::MERCHANTS_FILE).and_return(true)
      allow(File).to receive(:read).with(described_class::MERCHANTS_FILE).and_return(
        { "merchants" => [{ "EPOS_NOW_API_KEY" => "k1" }] }.to_json
      )
      result = config.send(:load_merchants_file)
      expect(result.size).to eq(1)
    end

    it "returns empty array on JSON parse error" do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(described_class::MERCHANTS_FILE).and_return(true)
      allow(File).to receive(:read).with(described_class::MERCHANTS_FILE).and_return("invalid json!")
      expect(config.send(:load_merchants_file)).to eq([])
    end
  end

  describe "private #normalize_url" do
    it "adds trailing slash" do
      expect(config.send(:normalize_url, "https://api.example.com")).to eq("https://api.example.com/")
    end

    it "keeps existing trailing slash" do
      expect(config.send(:normalize_url, "https://api.example.com/")).to eq("https://api.example.com/")
    end

    it "strips whitespace" do
      expect(config.send(:normalize_url, "  https://api.example.com  ")).to eq("https://api.example.com/")
    end
  end

  describe "private #parse_log_level" do
    it "parses DEBUG" do
      expect(config.send(:parse_log_level, "DEBUG")).to eq(Logger::DEBUG)
    end

    it "parses WARN" do
      expect(config.send(:parse_log_level, "WARN")).to eq(Logger::WARN)
    end

    it "parses ERROR" do
      expect(config.send(:parse_log_level, "ERROR")).to eq(Logger::ERROR)
    end

    it "parses FATAL" do
      expect(config.send(:parse_log_level, "FATAL")).to eq(Logger::FATAL)
    end

    it "defaults to INFO for unknown levels" do
      expect(config.send(:parse_log_level, "UNKNOWN")).to eq(Logger::INFO)
    end

    it "is case-insensitive" do
      expect(config.send(:parse_log_level, "debug")).to eq(Logger::DEBUG)
    end
  end
end
