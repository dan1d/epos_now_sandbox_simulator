# frozen_string_literal: true

module EposNowSandboxSimulator
  module Services
    module EposNow
      # Manages categories and products in Epos Now via V4 API.
      #
      # V4 endpoints:
      #   GET/POST/PUT/DELETE /api/v4/Category
      #   GET/POST/PUT/DELETE /api/v4/Product
      #
      # V4 key changes from V2:
      #   - Id instead of CategoryID/ProductID
      #   - POST/PUT/DELETE accept arrays (batch operations)
      #   - Product: IsSalePriceIncTax, IsEatOutPriceIncTax, IsArchived, ColourId
      #   - Category: ImageUrl, Children (nested), RootParentId
      class InventoryService < BaseService
        # ==========================================
        # CATEGORIES
        # ==========================================

        # Fetch all categories (paginated, 200 per page)
        # @return [Array<Hash>] All categories
        def fetch_categories
          logger.info "Fetching all categories..."
          categories = fetch_all_pages("Category")
          logger.info "Fetched #{categories.size} categories"
          categories
        end

        # Create a category
        # @param name [String] Category name
        # @param description [String, nil] Description
        # @param show_on_till [Boolean] Show on till (default true)
        # @param sort_position [Integer, nil] Sort order
        # @param parent_id [Integer, nil] Parent category ID
        # @param nominal_code [String, nil] Accounting software identifier
        # @return [Hash] Created category
        def create_category(name:, description: nil, show_on_till: true, sort_position: nil, parent_id: nil, nominal_code: nil)
          payload = {
            "Name" => name,
            "ShowOnTill" => show_on_till,
            "IsWet" => false
          }
          payload["Description"] = description if description
          payload["SortPosition"] = sort_position if sort_position
          payload["ParentId"] = parent_id if parent_id
          payload["NominalCode"] = nominal_code if nominal_code

          logger.info "Creating category: #{name}"
          result = request(:post, endpoint("Category"), payload: payload, resource_type: "Category")
          logger.info "Created category: #{result["Name"]} (ID: #{result["Id"]})"
          result
        end

        # Find category by name
        # @param name [String] Category name to search
        # @return [Hash, nil] Category or nil
        def find_category_by_name(name)
          # V4: use search parameter
          results = request(:get, endpoint("Category"), params: { "Name" => name }, resource_type: "Category")
          return nil unless results.is_a?(Array)

          results.find { |c| c["Name"]&.downcase == name.downcase }
        end

        # Create category idempotently (find or create)
        # @return [Hash] Existing or new category
        def find_or_create_category(name:, description: nil, show_on_till: true, sort_position: nil, parent_id: nil, nominal_code: nil)
          existing = find_category_by_name(name)
          return existing if existing

          create_category(
            name: name,
            description: description,
            show_on_till: show_on_till,
            sort_position: sort_position,
            parent_id: parent_id,
            nominal_code: nominal_code
          )
        end

        # Delete a category (V4: uses request body)
        # @param id [Integer] Category ID
        def delete_category(id)
          request(:delete, endpoint("Category"), payload: [{ "Id" => id }], resource_type: "Category", resource_id: id.to_s)
        end

        # ==========================================
        # PRODUCTS (Items)
        # ==========================================

        # Fetch all products (paginated, 200 per page)
        # @return [Array<Hash>] All products
        def fetch_products
          logger.info "Fetching all products..."
          products = fetch_all_pages("Product")
          logger.info "Fetched #{products.size} products"
          products
        end

        # Get a single product by ID
        # @param id [Integer] Product ID
        # @return [Hash] Product
        def get_product(id)
          request(:get, endpoint("Product/#{id}"), resource_type: "Product", resource_id: id.to_s)
        end

        # Create a product
        # @param name [String] Product name
        # @param sale_price [Float] Sale price
        # @param cost_price [Float] Cost price
        # @param eat_out_price [Float, nil] Takeaway price (defaults to sale_price)
        # @param category_id [Integer, nil] Category ID
        # @param barcode [String, nil] Barcode
        # @param sku [String, nil] SKU
        # @param description [String, nil] Description
        # @param sell_on_till [Boolean] Show on till
        # @return [Hash] Created product
        def create_product(name:, sale_price:, cost_price: 0.0, eat_out_price: nil, category_id: nil,
                           barcode: nil, sku: nil, description: nil, sell_on_till: true)
          payload = {
            "Name" => name,
            "SalePrice" => sale_price,
            "CostPrice" => cost_price,
            "EatOutPrice" => eat_out_price || sale_price,
            "SellOnTill" => sell_on_till,
            "SellOnWeb" => false,
            "ProductType" => 0 # Standard
          }
          payload["CategoryId"] = category_id if category_id
          payload["Barcode"] = barcode if barcode
          payload["Sku"] = sku if sku
          payload["Description"] = description if description

          logger.info "Creating product: #{name} ($#{sale_price})"
          result = request(:post, endpoint("Product"), payload: payload, resource_type: "Product")
          logger.info "Created product: #{result["Name"]} (ID: #{result["Id"]})"
          result
        end

        # Find product by name
        # @param name [String] Product name
        # @return [Hash, nil] Product or nil
        def find_product_by_name(name)
          results = request(:get, endpoint("Product"), params: { "Name" => name }, resource_type: "Product")
          return nil unless results.is_a?(Array)

          results.find { |p| p["Name"]&.downcase == name.downcase }
        end

        # Create product idempotently
        def find_or_create_product(name:, sale_price:, cost_price: 0.0, eat_out_price: nil,
                                   category_id: nil, barcode: nil, sku: nil, description: nil)
          existing = find_product_by_name(name)
          return existing if existing

          create_product(
            name: name,
            sale_price: sale_price,
            cost_price: cost_price,
            eat_out_price: eat_out_price,
            category_id: category_id,
            barcode: barcode,
            sku: sku,
            description: description
          )
        end

        # Delete a product (V4: uses request body)
        # @param id [Integer] Product ID
        def delete_product(id)
          request(:delete, endpoint("Product"), payload: [{ "Id" => id }], resource_type: "Product", resource_id: id.to_s)
        end
      end
    end
  end
end
