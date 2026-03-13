# frozen_string_literal: true

module EposNowSandboxSimulator
  module Services
    module EposNow
      # Manages tax groups in Epos Now via V4 API.
      #
      # V4 endpoints:
      #   GET/POST/PUT/DELETE /api/v4/TaxGroup
      #   GET /api/v4/TaxGroup/{id}
      #
      # V4 TaxGroup model:
      #   Id, Name, TaxRates[] (array of TaxGroupRate)
      #
      # TaxGroupRate:
      #   TaxGroupId, TaxRateId, LocationId, Priority, Percentage, Name, Description, TaxCode
      class TaxService < BaseService
        # Fetch all tax groups
        # @return [Array<Hash>] All tax groups
        def fetch_tax_groups
          logger.info "Fetching tax groups..."
          groups = fetch_all_pages("TaxGroup")
          logger.info "Fetched #{groups.size} tax groups"
          groups
        end

        # Get a single tax group by ID
        # @param id [Integer] Tax group ID
        # @return [Hash] Tax group with nested TaxRates
        def get_tax_group(id)
          request(:get, endpoint("TaxGroup/#{id}"), resource_type: "TaxGroup", resource_id: id.to_s)
        end

        # Calculate tax for a given amount using the configured rate
        # @param amount [Float] Pre-tax amount
        # @param rate [Float, nil] Tax rate percentage (uses config default)
        # @return [Float] Tax amount
        def calculate_tax(amount, rate: nil)
          tax_rate = rate || config.tax_rate
          (amount * tax_rate / 100.0).round(2)
        end
      end
    end
  end
end
