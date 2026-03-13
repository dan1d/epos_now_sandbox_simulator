# frozen_string_literal: true

module EposNowSandboxSimulator
  module Services
    module EposNow
      # Manages transactions in Epos Now via V4 API.
      #
      # V4 endpoints:
      #   GET    /api/v4/Transaction              - list (params: status, page)
      #   POST   /api/v4/Transaction              - create
      #   GET    /api/v4/Transaction/{id}          - get by id
      #   PUT    /api/v4/Transaction/{id}          - update
      #   DELETE /api/v4/Transaction/{id}          - delete
      #   GET    /api/v4/Transaction/GetByDate     - filter by date range
      #   GET    /api/v4/Transaction/GetLatest     - latest transactions
      #   POST   /api/v4/Transaction/Validate      - validate without saving
      #
      # V4 Transaction model:
      #   Id, CustomerId, StaffId, TableId, DeviceId, DateTime,
      #   StatusId, Barcode, ServiceType, TotalAmount, ServiceCharge,
      #   Gratuity, DiscountValue, DiscountReasonId, ReferenceCode,
      #   TransactionItems[], Tenders[], Taxes[]
      #
      # V4 ServiceType values (replaces V2 EatOut):
      #   0 = EatIn, 1 = Takeaway, 2 = Delivery
      #
      # V4 key difference: Tenders are embedded in Transaction creation,
      # not separate CRUD entities.
      class TransactionService < BaseService
        # ServiceType values (V4)
        EAT_IN = 0
        TAKEAWAY = 1
        DELIVERY = 2

        # Fetch transactions (paginated)
        # @param page [Integer, nil] Page number
        # @param status [Integer, nil] Status filter
        # @return [Array<Hash>] Transactions
        def fetch_transactions(page: nil, status: nil)
          if page
            params = { page: page }
            params[:status] = status if status
            request(:get, endpoint("Transaction"), params: params, resource_type: "Transaction") || []
          else
            fetch_all_pages("Transaction")
          end
        end

        # Fetch transactions by date range (V4-specific endpoint)
        # @param start_date [String, Date] Start date (ISO 8601)
        # @param end_date [String, Date] End date (ISO 8601)
        # @param device_id [Integer, nil] Filter by device
        # @param status [Integer, nil] Filter by status
        # @return [Array<Hash>] Transactions in range
        def fetch_transactions_by_date(start_date:, end_date:, device_id: nil, status: nil)
          params = {
            startDate: start_date.to_s,
            endDate: end_date.to_s
          }
          params[:deviceId] = device_id if device_id
          params[:status] = status if status

          all_records = []
          page = 1

          loop do
            page_params = params.merge(page: page)
            results = request(:get, endpoint("Transaction/GetByDate"), params: page_params, resource_type: "Transaction")
            records = results.is_a?(Array) ? results : []
            break if records.empty?

            all_records.concat(records)
            break if records.size < 200

            page += 1
          end

          all_records
        end

        # Fetch latest transactions
        # @param device_id [Integer, nil] Filter by device
        # @param status [Integer, nil] Filter by status
        # @return [Array<Hash>] Latest transactions
        def fetch_latest_transactions(device_id: nil, status: nil)
          params = {}
          params[:deviceId] = device_id if device_id
          params[:status] = status if status

          request(:get, endpoint("Transaction/GetLatest"), params: params, resource_type: "Transaction") || []
        end

        # Get a single transaction by ID
        # @param id [Integer] Transaction ID
        # @param lock [Boolean] Lock the transaction
        # @return [Hash] Transaction
        def get_transaction(id, lock: false)
          path = lock ? "Transaction/#{id}/true" : "Transaction/#{id}/false"
          request(:get, endpoint(path), resource_type: "Transaction", resource_id: id.to_s)
        end

        # Create a complete transaction with items and tenders (V4 style)
        #
        # In V4, TransactionItems and Tenders are embedded in the
        # Transaction creation payload — no separate API calls needed.
        #
        # @param items [Array<Hash>] Array of {product_id:, quantity:, unit_price:}
        # @param tenders [Array<Hash>] Array of {tender_type_id:, amount:, change_given:}
        # @param service_type [Integer] 0=EatIn, 1=Takeaway, 2=Delivery
        # @param staff_id [Integer, nil] Staff member
        # @param customer_id [Integer, nil] Customer
        # @param gratuity [Float] Tip amount
        # @param discount_value [Float] Discount amount
        # @param service_charge [Float] Service charge amount
        # @return [Hash] Created transaction with embedded items and tenders
        def create_transaction(items:, tenders:, service_type: EAT_IN, staff_id: nil,
                               customer_id: nil, gratuity: 0.0, discount_value: 0.0, service_charge: 0.0)
          # Build V4 TransactionItems
          transaction_items = items.map do |item|
            ti = {
              "ProductId" => item[:product_id],
              "Quantity" => item[:quantity] || 1
            }
            ti["UnitPrice"] = item[:unit_price] if item[:unit_price]
            ti["DiscountAmount"] = item[:discount] if item[:discount]&.positive?
            ti["Notes"] = item[:notes] if item[:notes]
            ti
          end

          # Build V4 Tenders
          transaction_tenders = tenders.map do |tender|
            {
              "TenderTypeId" => tender[:tender_type_id],
              "Amount" => tender[:amount],
              "ChangeGiven" => tender[:change_given] || 0.0
            }
          end

          payload = {
            "ServiceType" => service_type,
            "Gratuity" => gratuity,
            "DiscountValue" => discount_value,
            "ServiceCharge" => service_charge,
            "TransactionItems" => transaction_items,
            "Tenders" => transaction_tenders
          }
          payload["StaffId"] = staff_id if staff_id
          payload["CustomerId"] = customer_id if customer_id

          logger.info "Creating transaction (ServiceType=#{service_type}, #{items.size} items, #{tenders.size} tenders)"
          result = request(:post, endpoint("Transaction"), payload: payload, resource_type: "Transaction")
          logger.info "Created transaction ID: #{result["Id"]}"
          result
        end

        # Delete a transaction (V4: uses request body)
        # @param id [Integer] Transaction ID
        def delete_transaction(id)
          request(:delete, endpoint("Transaction/#{id}"), resource_type: "Transaction", resource_id: id.to_s)
        end

        # Validate a transaction without saving
        # @param payload [Hash] Transaction payload
        # @return [Hash] Validation result
        def validate_transaction(payload)
          request(:post, endpoint("Transaction/Validate"), payload: payload, resource_type: "Transaction")
        end
      end
    end
  end
end
