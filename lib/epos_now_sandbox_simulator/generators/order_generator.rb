# frozen_string_literal: true

require "faker"

module EposNowSandboxSimulator
  module Generators
    # Generates realistic daily orders in Epos Now via V4 API.
    #
    # V4 differences from V2:
    #   - ServiceType (0=EatIn, 1=Takeaway, 2=Delivery) replaces EatOut
    #   - TransactionItems and Tenders are embedded in the Transaction payload
    #   - Field names: Id instead of TransactionID, TenderTypeId instead of TypeID
    #   - GetByDate endpoint for date-range queries
    #
    # @example Generate orders for today
    #   generator = OrderGenerator.new
    #   orders = generator.generate_today(count: 25)
    #
    # @example Generate a full realistic day
    #   generator = OrderGenerator.new
    #   orders = generator.generate_realistic_day(multiplier: 1.5)
    class OrderGenerator
      # Meal period definitions
      MEAL_PERIODS = {
        breakfast: { hours: (7..10), weight: 15, avg_items: (2..5), avg_party: (1..3) },
        lunch: { hours: (11..14), weight: 30, avg_items: (3..7), avg_party: (1..4) },
        happy_hour: { hours: (15..17), weight: 10, avg_items: (2..5), avg_party: (2..5) },
        dinner: { hours: (17..21), weight: 35, avg_items: (3..9), avg_party: (2..6) },
        late_night: { hours: (21..23), weight: 10, avg_items: (2..5), avg_party: (1..3) }
      }.freeze

      # Dining option weights by meal period
      DINING_BY_PERIOD = {
        breakfast: { eat_in: 40, takeaway: 50, delivery: 10 },
        lunch: { eat_in: 35, takeaway: 45, delivery: 20 },
        happy_hour: { eat_in: 80, takeaway: 15, delivery: 5 },
        dinner: { eat_in: 70, takeaway: 15, delivery: 15 },
        late_night: { eat_in: 50, takeaway: 30, delivery: 20 }
      }.freeze

      # V4 ServiceType mapping
      SERVICE_TYPE_MAP = {
        eat_in: 0,     # EatIn
        takeaway: 1,   # Takeaway
        delivery: 2    # Delivery
      }.freeze

      # Day-of-week order counts
      ORDER_PATTERNS = {
        monday: (40..60), tuesday: (40..60), wednesday: (40..60),
        thursday: (45..65), friday: (70..100), saturday: (80..120),
        sunday: (50..80)
      }.freeze

      # Tip percentages by dining option
      TIP_RATES = {
        eat_in: { min: 15, max: 25 },
        takeaway: { min: 0,  max: 15 },
        delivery: { min: 10, max: 20 }
      }.freeze

      attr_reader :refund_percentage

      def initialize(refund_percentage: 5, config: nil)
        @config = config || EposNowSandboxSimulator.configuration
        @services = Services::EposNow::ServicesManager.new(config: @config)
        @refund_percentage = refund_percentage
        @data_loader = DataLoader.new(business_type: @config.business_type)
      end

      # Generate orders for today
      # @param count [Integer, nil] Number of orders (nil = random based on day)
      # @return [Array<Hash>] Generated orders
      def generate_today(count: nil)
        data = fetch_required_data
        count ||= daily_order_count

        logger.info "Generating #{count} orders for today..."

        orders = distribute_across_periods(count).flat_map do |period, period_count|
          period_count.times.map do
            generate_single_order(data, period: period)
          end
        end

        logger.info "Generated #{orders.compact.size} orders"

        # Process refunds
        process_refunds(orders.compact) if refund_percentage.positive?

        # Generate daily summary
        generate_summary if Database.connected?

        orders.compact
      end

      # Generate a realistic full day
      # @param multiplier [Float] Volume multiplier (0.5 = slow, 2.0 = busy)
      # @return [Array<Hash>] All generated orders
      def generate_realistic_day(multiplier: 1.0)
        count = (daily_order_count * multiplier).round
        generate_today(count: count)
      end

      # Generate orders for a specific meal period
      # @param period [Symbol] Meal period
      # @param count [Integer] Number of orders
      # @return [Array<Hash>] Generated orders
      def generate_rush(period:, count: 15)
        data = fetch_required_data
        logger.info "Generating #{period} rush: #{count} orders..."

        orders = count.times.map do
          generate_single_order(data, period: period)
        end

        orders.compact
      end

      private

      def logger
        EposNowSandboxSimulator.logger
      end

      # Fetch all required data (products, tender types)
      def fetch_required_data
        products = @services.inventory.fetch_products
        tender_types = @services.tender.fetch_tender_types
        tenders_config = @data_loader.load_tenders

        raise Error, "No products found. Run setup first." if products.empty?
        raise Error, "No tender types found. Run setup first." if tender_types.empty?

        {
          products: products,
          tender_types: tender_types,
          tenders_config: tenders_config
        }
      end

      # Generate a single complete order using V4 API
      def generate_single_order(data, period:)
        dining_option = weighted_select(DINING_BY_PERIOD[period])
        service_type = SERVICE_TYPE_MAP[dining_option]
        item_count = rand(MEAL_PERIODS[period][:avg_items])

        # Pick random products
        selected_products = data[:products].sample(item_count)
        return nil if selected_products.empty?

        # Calculate totals
        subtotal = selected_products.sum { |p| p["SalePrice"].to_f }
        discount = calculate_discount(subtotal)
        tax = @services.tax.calculate_tax(subtotal - discount)
        tip = calculate_tip(subtotal, dining_option)
        total = subtotal - discount + tax + tip

        # Select tender (payment method)
        tender_type = select_tender(data[:tender_types], data[:tenders_config])

        # Build V4 items payload (embedded in transaction)
        items = selected_products.map do |product|
          {
            product_id: product["Id"],
            quantity: 1,
            unit_price: product["SalePrice"].to_f
          }
        end

        # Build V4 tenders payload (embedded in transaction)
        tenders = [{
          tender_type_id: tender_type["Id"],
          amount: total.round(2),
          change_given: 0.0
        }]

        # Create the complete transaction via V4 API (single call)
        result = @services.transaction.create_transaction(
          items: items,
          tenders: tenders,
          service_type: service_type,
          gratuity: tip.round(2),
          discount_value: discount.round(2)
        )

        # Persist locally if DB is connected
        persist_order(result, period, dining_option, subtotal, tax, tip, discount, total, tender_type) if Database.connected?

        total_str = format("%.2f", total)
        logger.info "Order #{result["Id"]}: #{selected_products.size} items, $#{total_str} (#{dining_option}, #{tender_type["Name"]})"
        result
      rescue StandardError => e
        logger.error "Failed to generate order: #{e.message}"
        nil
      end

      # Persist order to local DB for tracking
      def persist_order(result, period, dining_option, subtotal, tax, tip, discount, total, tender_type)
        order = Models::SimulatedOrder.create!(
          epos_now_transaction_id: result["Id"],
          status: "paid",
          business_date: @config.merchant_date_today,
          dining_option: dining_option.to_s,
          meal_period: period.to_s,
          subtotal: (subtotal * 100).round,
          tax_amount: (tax * 100).round,
          tip_amount: (tip * 100).round,
          discount_amount: (discount * 100).round,
          total: (total * 100).round,
          metadata: { items_count: (result["TransactionItems"] || []).size }
        )

        Models::SimulatedPayment.create!(
          simulated_order: order,
          epos_now_tender_id: (result["Tenders"]&.first || {})["Id"],
          tender_name: tender_type["Name"],
          amount: (total * 100).round,
          tip_amount: (tip * 100).round,
          status: "success",
          payment_type: tender_type["Name"]&.downcase&.gsub(" ", "_")
        )
      rescue StandardError => e
        logger.debug "Failed to persist order: #{e.message}"
      end

      # Distribute orders across meal periods based on weights
      def distribute_across_periods(total_count)
        total_weight = MEAL_PERIODS.values.sum { |p| p[:weight] }
        distribution = {}

        MEAL_PERIODS.each do |period, config|
          count = (total_count.to_f * config[:weight] / total_weight).round
          distribution[period] = count if count.positive?
        end

        # Ensure we match the total
        diff = total_count - distribution.values.sum
        distribution[:dinner] = (distribution[:dinner] || 0) + diff if diff != 0

        distribution
      end

      # Calculate random daily order count based on day of week
      def daily_order_count
        day = @config.merchant_date_today.strftime("%A").downcase.to_sym
        range = ORDER_PATTERNS[day] || (40..60)
        rand(range)
      end

      # Weighted random selection
      def weighted_select(weights)
        total = weights.values.sum
        roll = rand(total)
        cumulative = 0

        weights.each do |key, weight|
          cumulative += weight
          return key if roll < cumulative
        end

        weights.keys.last
      end

      # Select a tender type based on weights from JSON config
      def select_tender(tender_types, tenders_config)
        weights = {}
        tenders_config.each do |tc|
          matching = tender_types.find { |tt| tt["Name"]&.downcase == tc["name"]&.downcase }
          weights[matching] = tc["weight"] if matching
        end

        return tender_types.first if weights.empty?

        weighted_select(weights)
      end

      # Calculate discount (8% chance of 10-20% discount)
      def calculate_discount(subtotal)
        return 0.0 if rand(100) >= 8

        rate = rand(10..20) / 100.0
        (subtotal * rate).round(2)
      end

      # Calculate tip based on dining option
      def calculate_tip(subtotal, dining_option)
        rates = TIP_RATES[dining_option] || TIP_RATES[:eat_in]

        # Tip probability varies by dining option
        tip_chance = case dining_option
                     when :eat_in then 70
                     when :takeaway then 40
                     when :delivery then 60
                     else 50
                     end

        return 0.0 if rand(100) >= tip_chance

        rate = rand(rates[:min]..rates[:max]) / 100.0
        (subtotal * rate).round(2)
      end

      # Process refunds on a percentage of orders
      def process_refunds(orders)
        return if orders.empty?

        refund_count = (orders.size * refund_percentage / 100.0).ceil
        return if refund_count.zero?

        logger.info "Processing #{refund_count} refunds..."

        orders.sample(refund_count).each do |order|
          transaction_id = order["Id"]
          next unless transaction_id

          # Mark as refunded in local DB
          if Database.connected?
            simulated = Models::SimulatedOrder.find_by(epos_now_transaction_id: transaction_id)
            simulated&.update!(status: "refunded")
          end

          logger.info "Refunded transaction #{transaction_id}"
        end
      end

      # Generate daily summary
      def generate_summary
        Models::DailySummary.generate_for!(@config.merchant_date_today)
        logger.info "Daily summary generated"
      rescue StandardError => e
        logger.debug "Failed to generate summary: #{e.message}"
      end
    end
  end
end
