# frozen_string_literal: true

module EposNowSandboxSimulator
  module Models
    class DailySummary < ActiveRecord::Base
      self.table_name = "daily_summaries"

      validates :summary_date, presence: true, uniqueness: true

      # Generate or update a daily summary for a given date
      # @param date [Date] The date to summarize
      # @return [DailySummary]
      def self.generate_for!(date)
        orders = SimulatedOrder.for_date(date).paid
        payments = SimulatedPayment.successful.joins(:simulated_order)
                                   .where(simulated_orders: { business_date: date, status: "paid" })

        attrs = {
          order_count: orders.count,
          payment_count: payments.count,
          refund_count: SimulatedOrder.for_date(date).refunded.count,
          total_revenue: orders.sum(:total),
          total_tax: orders.sum(:tax_amount),
          total_tips: orders.sum(:tip_amount),
          total_discounts: orders.sum(:discount_amount),
          breakdown: build_breakdown(orders, payments)
        }

        summary = find_or_initialize_by(summary_date: date)
        summary.update!(attrs)
        summary
      end

      def self.build_breakdown(orders, payments)
        {
          by_meal_period: orders.group(:meal_period).sum(:total),
          by_dining_option: orders.group(:dining_option).sum(:total),
          by_tender: payments.group(:tender_name).sum(:amount)
        }
      end
    end
  end
end
