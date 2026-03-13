# frozen_string_literal: true

module EposNowSandboxSimulator
  module Generators
    # Sets up all POS entities in Epos Now: categories, products, tender types.
    #
    # All operations are idempotent — safe to run multiple times.
    #
    # @example
    #   generator = EntityGenerator.new(business_type: :restaurant)
    #   generator.setup_all
    class EntityGenerator
      attr_reader :business_type, :services, :data_loader

      def initialize(business_type: :restaurant, config: nil)
        @business_type = business_type.to_sym
        @config = config || EposNowSandboxSimulator.configuration
        @services = Services::EposNow::ServicesManager.new(config: @config)
        @data_loader = DataLoader.new(business_type: @business_type)
      end

      # Set up everything: categories, products, tender types
      def setup_all
        logger.info "Setting up #{business_type} entities..."

        tender_types = setup_tender_types
        categories = setup_categories
        products = setup_products(categories)

        stats = {
          tender_types: tender_types.size,
          categories: categories.size,
          products: products.size
        }

        logger.info "Setup complete: #{stats}"
        stats
      end

      # Create tender types from JSON data
      # @return [Array<Hash>] Created/existing tender types
      def setup_tender_types
        tenders_data = data_loader.load_tenders
        logger.info "Setting up #{tenders_data.size} tender types..."

        tenders_data.map do |td|
          services.tender.find_or_create_tender_type(
            name: td["name"],
            description: td["description"]
          )
        end
      end

      # Create categories from JSON data
      # @return [Hash<String, Hash>] Category name => Epos Now category response
      def setup_categories
        categories_data = data_loader.load_categories
        logger.info "Setting up #{categories_data.size} categories..."

        result = {}
        categories_data.each do |cat|
          epos_cat = services.inventory.find_or_create_category(
            name: cat["name"],
            description: cat["description"],
            show_on_till: true,
            sort_position: cat["sort_order"]
          )
          result[cat["name"]] = epos_cat
        end

        result
      end

      # Create products from JSON data, linked to categories
      # @param categories [Hash<String, Hash>] Category name => Epos Now category
      # @return [Array<Hash>] Created/existing products
      def setup_products(categories = nil)
        categories ||= setup_categories
        items_data = data_loader.load_items
        logger.info "Setting up #{items_data.size} products..."

        items_data.map do |item|
          category = categories[item["category"]]
          category_id = category&.dig("Id")

          services.inventory.find_or_create_product(
            name: item["name"],
            sale_price: item["price"],
            cost_price: (item["price"] * 0.35).round(2), # ~35% cost
            category_id: category_id,
            barcode: item["sku"]
          )
        end
      end

      private

      def logger
        EposNowSandboxSimulator.logger
      end
    end
  end
end
