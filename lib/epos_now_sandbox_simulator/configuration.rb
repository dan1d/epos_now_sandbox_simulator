# frozen_string_literal: true

module EposNowSandboxSimulator
  class Configuration
    attr_accessor :api_key, :api_secret, :environment, :log_level, :tax_rate, :business_type,
                  :device_name, :merchant_timezone

    # Default timezone if not configured
    DEFAULT_TIMEZONE = "America/Los_Angeles"

    # Path to merchants JSON file
    MERCHANTS_FILE = File.join(File.dirname(__FILE__), "..", "..", ".env.json")

    # Epos Now API base URL
    DEFAULT_API_URL = "https://api.eposnowhq.com"

    def initialize
      @api_key       = ENV.fetch("EPOS_NOW_API_KEY", nil)
      @api_secret    = ENV.fetch("EPOS_NOW_API_SECRET", nil)
      @device_name   = ENV.fetch("EPOS_NOW_DEVICE_NAME", nil)
      @environment   = normalize_url(ENV.fetch("EPOS_NOW_API_URL", DEFAULT_API_URL))
      @log_level     = parse_log_level(ENV.fetch("LOG_LEVEL", "INFO"))
      @tax_rate      = ENV.fetch("TAX_RATE", "8.25").to_f
      @business_type = ENV.fetch("BUSINESS_TYPE", "restaurant").to_sym
      @merchant_timezone = ENV.fetch("MERCHANT_TIMEZONE", DEFAULT_TIMEZONE)

      # Load from .env.json if api_key not set in ENV
      load_from_merchants_file if @api_key.nil? || @api_key.empty?
    end

    # Build the Basic Auth token from API Key + Secret
    # Epos Now: Base64(api_key:api_secret)
    #
    # @return [String] Base64-encoded credentials
    def auth_token
      require "base64"
      Base64.strict_encode64("#{api_key}:#{api_secret}")
    end

    # Load configuration for a specific device from .env.json
    #
    # @param device_name [String, nil] Device name to load
    # @param index [Integer, nil] Index of device in the list (0-based)
    # @return [self]
    def load_merchant(device_name: nil, index: nil)
      merchants = load_merchants_file
      return self if merchants.empty?

      merchant = if device_name
                   merchants.find { |m| m["EPOS_NOW_DEVICE_NAME"] == device_name }
                 elsif index
                   merchants[index]
                 else
                   merchants.first
                 end

      if merchant
        apply_merchant_config(merchant)
        logger.info "Loaded device: #{@device_name}"
      else
        logger.warn "Device not found: #{device_name || "index #{index}"}"
      end

      self
    end

    # List all available devices from .env.json
    #
    # @return [Array<Hash>] Array of device configs
    def available_merchants
      load_merchants_file.map do |m|
        {
          name: m["EPOS_NOW_DEVICE_NAME"],
          has_credentials: !m["EPOS_NOW_API_KEY"].to_s.empty? && !m["EPOS_NOW_API_SECRET"].to_s.empty?
        }
      end
    end

    def validate!
      raise ConfigurationError, "EPOS_NOW_API_KEY is required" if api_key.nil? || api_key.empty?
      raise ConfigurationError, "EPOS_NOW_API_SECRET is required" if api_secret.nil? || api_secret.empty?

      true
    end

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.level = @log_level
        log.formatter = proc do |severity, datetime, _progname, msg|
          timestamp = datetime.strftime("%Y-%m-%d %H:%M:%S")
          "[#{timestamp}] #{severity.ljust(5)} | #{msg}\n"
        end
      end
    end

    # Get current time in merchant's timezone
    # @return [Time] Current time in merchant timezone
    def merchant_time_now
      require "time"
      begin
        require "tzinfo"
        TZInfo::Timezone.get(merchant_timezone).now
      rescue LoadError
        old_tz = ENV.fetch("TZ", nil)
        ENV["TZ"] = merchant_timezone
        time = Time.now
        ENV["TZ"] = old_tz
        time
      end
    end

    # Get today's date in merchant's timezone
    # @return [Date] Today's date in merchant timezone
    def merchant_date_today
      merchant_time_now.to_date
    end

    private

    def load_from_merchants_file
      merchants = load_merchants_file
      return if merchants.empty?

      apply_merchant_config(merchants.first)
    end

    # Parse .env.json, supporting both array and object formats
    def load_merchants_file
      return [] unless File.exist?(MERCHANTS_FILE)

      data = JSON.parse(File.read(MERCHANTS_FILE))
      return data if data.is_a?(Array)

      data.fetch("merchants", [])
    rescue JSON::ParserError => e
      warn "Failed to parse #{MERCHANTS_FILE}: #{e.message}"
      []
    end

    # Read the top-level DATABASE_URL from .env.json
    def self.database_url_from_file
      return nil unless File.exist?(MERCHANTS_FILE)

      data = JSON.parse(File.read(MERCHANTS_FILE))
      return nil if data.is_a?(Array)

      data["DATABASE_URL"]
    rescue JSON::ParserError
      nil
    end

    def apply_merchant_config(merchant)
      @api_key     = merchant["EPOS_NOW_API_KEY"] unless merchant["EPOS_NOW_API_KEY"].to_s.empty?
      @api_secret  = merchant["EPOS_NOW_API_SECRET"] unless merchant["EPOS_NOW_API_SECRET"].to_s.empty?
      @device_name = merchant["EPOS_NOW_DEVICE_NAME"] unless merchant["EPOS_NOW_DEVICE_NAME"].to_s.empty?
    end

    def normalize_url(url)
      url = url.strip
      url.end_with?("/") ? url : "#{url}/"
    end

    def parse_log_level(level)
      {
        "DEBUG" => Logger::DEBUG,
        "INFO" => Logger::INFO,
        "WARN" => Logger::WARN,
        "ERROR" => Logger::ERROR,
        "FATAL" => Logger::FATAL
      }.fetch(level.to_s.upcase, Logger::INFO)
    end
  end
end
