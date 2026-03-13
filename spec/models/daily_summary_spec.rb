# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Models::DailySummary do
  describe ".generate_for!" do
    let(:date) { Date.new(2026, 3, 13) }
    let(:orders_relation) { double("orders") }
    let(:paid_relation) { double("paid_orders") }
    let(:refunded_relation) { double("refunded_orders") }
    let(:payments_relation) { double("payments") }
    let(:summary_double) { double("summary") }

    before do
      for_date_relation = double("for_date")
      allow(EposNowSandboxSimulator::Models::SimulatedOrder).to receive(:for_date).with(date).and_return(for_date_relation)
      allow(for_date_relation).to receive_messages(paid: paid_relation, refunded: refunded_relation)

      allow(EposNowSandboxSimulator::Models::SimulatedPayment).to receive(:successful).and_return(payments_relation)

      allow(paid_relation).to receive(:count).and_return(10)
      allow(paid_relation).to receive(:sum).with(:total).and_return(50_000)
      allow(paid_relation).to receive(:sum).with(:tax_amount).and_return(4_125)
      allow(paid_relation).to receive(:sum).with(:tip_amount).and_return(7_500)
      allow(paid_relation).to receive(:sum).with(:discount_amount).and_return(1_000)
      allow(refunded_relation).to receive(:count).and_return(1)
      allow(payments_relation).to receive_messages(joins: payments_relation, where: payments_relation, count: 10)

      allow(described_class).to receive(:build_breakdown).and_return({})
      allow(described_class).to receive(:find_or_initialize_by).with(summary_date: date).and_return(summary_double)
      allow(summary_double).to receive(:update!)
    end

    it "generates a summary for the date" do
      result = described_class.generate_for!(date)
      expect(result).to eq(summary_double)
    end

    it "updates the summary with correct attributes" do
      described_class.generate_for!(date)
      expect(summary_double).to have_received(:update!).with(hash_including(
                                                               order_count: 10,
                                                               payment_count: 10,
                                                               refund_count: 1,
                                                               total_revenue: 50_000,
                                                               total_tax: 4_125,
                                                               total_tips: 7_500,
                                                               total_discounts: 1_000
                                                             ))
    end
  end

  describe ".build_breakdown" do
    it "groups by meal_period, dining_option, and tender" do
      orders = double("orders")
      payments = double("payments")

      period_group = double("period_group")
      dining_group = double("dining_group")
      tender_group = double("tender_group")

      allow(orders).to receive(:group).with(:meal_period).and_return(period_group)
      allow(period_group).to receive(:sum).with(:total).and_return({ "lunch" => 10_000 })

      allow(orders).to receive(:group).with(:dining_option).and_return(dining_group)
      allow(dining_group).to receive(:sum).with(:total).and_return({ "eat_in" => 8_000 })

      allow(payments).to receive(:group).with(:tender_name).and_return(tender_group)
      allow(tender_group).to receive(:sum).with(:amount).and_return({ "Cash" => 5_000 })

      breakdown = described_class.build_breakdown(orders, payments)
      expect(breakdown[:by_meal_period]).to eq({ "lunch" => 10_000 })
      expect(breakdown[:by_dining_option]).to eq({ "eat_in" => 8_000 })
      expect(breakdown[:by_tender]).to eq({ "Cash" => 5_000 })
    end
  end
end
