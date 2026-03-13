# frozen_string_literal: true

module EposNowSandboxSimulator
  module Generators
    # Loads business data from DB (preferred) or JSON files (fallback).
    #
    # Returns identically-shaped hashes regardless of source.
    class DataLoader
      DATA_DIR = File.expand_path("../data", __dir__).freeze

      BUSINESS_TYPES = %i[restaurant cafe_bakery bar_nightclub retail_general].freeze

      attr_reader :business_type

      def initialize(business_type: :restaurant)
        @business_type = business_type.to_sym
      end

      # Load categories for the business type
      # @return [Array<Hash>] Categories with :name, :sort_order, :description
      def load_categories
        if Database.connected?
          load_categories_from_db
        else
          load_categories_from_json
        end
      end

      # Load items for the business type
      # @return [Array<Hash>] Items with :name, :price, :category, :sku
      def load_items
        if Database.connected?
          load_items_from_db
        else
          load_items_from_json
        end
      end

      # Load tender types
      # @return [Array<Hash>] Tenders with :name, :description, :weight
      def load_tenders
        load_from_json("tenders")["tenders"] || []
      end

      # Load items grouped by category
      # @return [Hash<String, Array<Hash>>] Category name => items
      def load_items_by_category
        items = load_items
        items.group_by { |i| i["category"] || i[:category] }
      end

      private

      def load_categories_from_db
        bt = Models::BusinessType.find_by(key: business_type.to_s)
        return load_categories_from_json unless bt

        bt.categories.order(:sort_order).map do |cat|
          { "name" => cat.name, "sort_order" => cat.sort_order, "description" => cat.description }
        end
      end

      def load_items_from_db
        bt = Models::BusinessType.find_by(key: business_type.to_s)
        return load_items_from_json unless bt

        bt.items.includes(:category).map do |item|
          {
            "name" => item.name,
            "price" => item.price / 100.0, # stored in cents
            "category" => item.category&.name,
            "sku" => item.sku
          }
        end
      end

      def load_categories_from_json
        load_from_json("categories")["categories"] || []
      end

      def load_items_from_json
        load_from_json("items")["items"] || []
      end

      def load_from_json(filename)
        path = File.join(DATA_DIR, business_type.to_s, "#{filename}.json")

        unless File.exist?(path)
          EposNowSandboxSimulator.logger.warn "Data file not found: #{path}"
          return {}
        end

        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        EposNowSandboxSimulator.logger.error "Failed to parse #{path}: #{e.message}"
        {}
      end
    end
  end
end
