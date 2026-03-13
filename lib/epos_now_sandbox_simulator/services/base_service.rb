# frozen_string_literal: true

require "base64"

module EposNowSandboxSimulator
  module Services
    # Base service for all Epos Now API interactions.
    #
    # Epos Now uses Basic Authentication: Base64(api_key:api_secret)
    # API Base: https://api.eposnowhq.com/api/v4/
    # Pagination: page-based, 200 items per page
    #
    # V4 differences from V2:
    #   - Field names: Id instead of CategoryID/ProductID/etc.
    #   - Batch operations: POST/PUT/DELETE accept arrays
    #   - DELETE uses request body [{Id: int}]
    #   - Transaction: ServiceType instead of EatOut, GetByDate endpoint
    #   - TenderType: ClassificationId, IsTipAdjustable fields
    class BaseService
      attr_reader :config, :logger

      # Epos Now API V4 path prefix
      API_PREFIX = "api/v4"

      def initialize(config: nil)
        @config = config || EposNowSandboxSimulator.configuration
        @config.validate!
        @logger = @config.logger
      end

      protected

      # Make HTTP request to Epos Now API
      #
      # @param method [Symbol] HTTP method (:get, :post, :put, :delete)
      # @param path [String] API endpoint path (e.g. "Category")
      # @param payload [Hash, nil] Request body for POST/PUT
      # @param params [Hash, nil] Query parameters
      # @param resource_type [String, nil] Logical resource (e.g. "Category")
      # @param resource_id [String, nil] Resource ID
      # @return [Hash, Array, nil] Parsed JSON response
      def request(method, path, payload: nil, params: nil, resource_type: nil, resource_id: nil)
        url = build_url(path, params)

        log_request(method, url, payload)
        start_time = Time.now

        response = execute_request(method, url, payload)

        duration_ms = ((Time.now - start_time) * 1000).round
        log_response(response, duration_ms)

        parsed = parse_response(response)

        audit_api_request(
          http_method: method.to_s.upcase,
          url: url,
          request_payload: payload,
          response_status: response.code,
          response_payload: parsed,
          duration_ms: duration_ms,
          resource_type: resource_type,
          resource_id: resource_id
        )

        parsed
      rescue RestClient::ExceptionWithResponse => e
        duration_ms = ((Time.now - start_time) * 1000).round

        audit_api_request(
          http_method: method.to_s.upcase,
          url: url,
          request_payload: payload,
          response_status: e.http_code,
          response_payload: begin
            JSON.parse(e.response.body)
          rescue StandardError
            nil
          end,
          duration_ms: duration_ms,
          error_message: "HTTP #{e.http_code}: #{e.message}",
          resource_type: resource_type,
          resource_id: resource_id
        )

        handle_api_error(e)
      rescue StandardError => e
        duration_ms = ((Time.now - start_time) * 1000).round

        audit_api_request(
          http_method: method.to_s.upcase,
          url: url,
          request_payload: payload,
          duration_ms: duration_ms,
          error_message: e.message,
          resource_type: resource_type,
          resource_id: resource_id
        )

        logger.error "Request failed: #{e.message}"
        raise ApiError, e.message
      end

      # Build endpoint path for Epos Now V4 API
      #
      # @param resource [String] Resource name (e.g. "Category", "Transaction")
      # @return [String] Full endpoint path
      def endpoint(resource)
        "#{API_PREFIX}/#{resource}"
      end

      # Fetch all pages of a paginated resource
      #
      # Epos Now returns up to 200 items per page.
      # Returns empty array when page returns no results.
      #
      # @param resource [String] Resource name
      # @param params [Hash] Additional query parameters
      # @return [Array<Hash>] All records across all pages
      def fetch_all_pages(resource, params: {})
        all_records = []
        page = 1

        loop do
          page_params = params.merge(page: page)
          results = request(:get, endpoint(resource), params: page_params, resource_type: resource)

          # Epos Now returns array directly or nil/empty for last page
          records = results.is_a?(Array) ? results : []
          break if records.empty?

          all_records.concat(records)

          # If we got fewer than 200, this is the last page
          break if records.size < 200

          page += 1
        end

        all_records
      end

      private

      def headers
        {
          "Authorization" => "Basic #{config.auth_token}",
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      end

      def build_url(path, params = nil)
        base = path.start_with?("http") ? path : "#{config.environment}#{path}"
        return base unless params&.any?

        uri = URI(base)
        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      def execute_request(method, url, payload)
        case method
        when :get    then RestClient.get(url, headers)
        when :post   then RestClient.post(url, payload&.to_json, headers)
        when :put    then RestClient.put(url, payload&.to_json, headers)
        when :delete
          # V4 DELETE uses request body [{Id: int}]
          if payload
            RestClient::Request.execute(method: :delete, url: url, payload: payload.to_json, headers: headers)
          else
            RestClient.delete(url, headers)
          end
        else raise ArgumentError, "Unsupported HTTP method: #{method}"
        end
      end

      def parse_response(response)
        return nil if response.body.nil? || response.body.empty?

        JSON.parse(response.body)
      rescue JSON::ParserError => e
        logger.error "Failed to parse response: #{e.message}"
        raise ApiError, "Invalid JSON response"
      end

      def handle_api_error(error)
        body = begin
          JSON.parse(error.response.body)
        rescue StandardError
          { "message" => error.response.body }
        end

        logger.error "API Error (#{error.http_code}): #{body}"
        raise ApiError, "HTTP #{error.http_code}: #{body["message"] || body}"
      end

      def log_request(method, url, payload)
        logger.debug "-> #{method.to_s.upcase} #{url}"
        logger.debug "  Payload: #{payload.inspect}" if payload
      end

      def log_response(response, duration_ms)
        logger.debug "<- #{response.code} (#{duration_ms}ms)"
      end

      # Persist an API request record for audit trail.
      # Silently no-ops when DB is not connected.
      def audit_api_request(http_method:, url:, request_payload: nil, response_status: nil, response_payload: nil, duration_ms: nil,
                            error_message: nil, resource_type: nil, resource_id: nil)
        return unless Database.connected?

        Models::ApiRequest.create!(
          http_method: http_method,
          url: url,
          request_payload: request_payload || {},
          response_payload: response_payload || {},
          response_status: response_status,
          duration_ms: duration_ms,
          error_message: error_message,
          resource_type: resource_type,
          resource_id: resource_id
        )
      rescue StandardError => e
        logger.debug "Audit logging failed: #{e.message}"
      end

      # Execute a block with API error fallback
      def with_api_fallback(fallback: nil, log_level: :debug)
        yield
      rescue ApiError => e
        logger.send(log_level, "API error (using fallback): #{e.message}")
        fallback
      rescue StandardError => e
        logger.send(log_level, "Error (using fallback): #{e.message}")
        fallback
      end

      def safe_dig(hash, *keys, default: nil)
        return default if hash.nil?

        hash.dig(*keys) || default
      rescue StandardError
        default
      end
    end
  end
end
