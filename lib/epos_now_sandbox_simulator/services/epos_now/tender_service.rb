# frozen_string_literal: true

module EposNowSandboxSimulator
  module Services
    module EposNow
      # Manages tender types (payment methods) in Epos Now via V4 API.
      #
      # V4 endpoints:
      #   GET/POST /api/v4/TenderType
      #   GET /api/v4/TenderType/{id}
      #
      # V4 TenderType fields:
      #   Id, Name, Description, IsIntegrationTenderType,
      #   TillOrder, ClassificationId, IsTipAdjustable, IsWaiterBanked
      #
      # V4 ClassificationId values:
      #   Cash, Card, Integrated, Other
      #
      # Note: In V4, individual Tenders (payments) are embedded in
      # Transaction creation — not a separate CRUD endpoint.
      class TenderService < BaseService
        # Default tender types for a typical POS setup
        DEFAULT_TENDER_TYPES = [
          { name: "Cash", description: "Cash payment" },
          { name: "Credit Card", description: "Credit card payment" },
          { name: "Debit Card", description: "Debit card payment" },
          { name: "Gift Card", description: "Gift card payment" },
          { name: "Check", description: "Check payment" }
        ].freeze

        # Fetch all tender types
        # @return [Array<Hash>] All tender types
        def fetch_tender_types
          logger.info "Fetching all tender types..."
          types = fetch_all_pages("TenderType")
          logger.info "Fetched #{types.size} tender types"
          types
        end

        # Get a single tender type by ID
        # @param id [Integer] Tender type ID
        # @return [Hash] Tender type
        def get_tender_type(id)
          request(:get, endpoint("TenderType/#{id}"), resource_type: "TenderType", resource_id: id.to_s)
        end

        # Create a tender type
        # @param name [String] Tender type name
        # @param description [String, nil] Description
        # @return [Hash] Created tender type
        def create_tender_type(name:, description: nil)
          payload = {
            "Name" => name
          }
          payload["Description"] = description if description

          logger.info "Creating tender type: #{name}"
          result = request(:post, endpoint("TenderType"), payload: payload, resource_type: "TenderType")
          logger.info "Created tender type: #{result["Name"]} (ID: #{result["Id"]})"
          result
        end

        # Find tender type by name
        # @param name [String] Tender type name
        # @return [Hash, nil] Tender type or nil
        def find_tender_type_by_name(name)
          types = fetch_tender_types
          types.find { |t| t["Name"]&.downcase == name.downcase }
        end

        # Create tender type idempotently
        def find_or_create_tender_type(name:, description: nil)
          existing = find_tender_type_by_name(name)
          return existing if existing

          create_tender_type(name: name, description: description)
        end

        # Ensure default tender types exist
        # @return [Array<Hash>] All tender types (existing + created)
        def setup_default_tender_types
          logger.info "Setting up default tender types..."
          DEFAULT_TENDER_TYPES.map do |tt|
            find_or_create_tender_type(name: tt[:name], description: tt[:description])
          end
        end
      end
    end
  end
end
