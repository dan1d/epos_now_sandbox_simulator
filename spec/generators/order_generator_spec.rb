# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Generators::OrderGenerator do
  let(:generator) { described_class.new(refund_percentage: 0) }
  let(:base_url) { "https://api.eposnowhq.com/api/v4" }

  let(:sample_products) do
    [
      { "Id" => 1, "Name" => "Coffee", "SalePrice" => 4.50 },
      { "Id" => 2, "Name" => "Muffin", "SalePrice" => 3.99 },
      { "Id" => 3, "Name" => "Sandwich", "SalePrice" => 8.99 }
    ]
  end

  let(:sample_tender_types) do
    [
      { "Id" => 1, "Name" => "Cash" },
      { "Id" => 2, "Name" => "Credit Card" }
    ]
  end

  before do
    # Stub product fetch
    stub_request(:get, "#{base_url}/Product?page=1")
      .to_return(status: 200, body: sample_products.to_json, headers: { "Content-Type" => "application/json" })

    # Stub tender type fetch
    stub_request(:get, "#{base_url}/TenderType?page=1")
      .to_return(status: 200, body: sample_tender_types.to_json, headers: { "Content-Type" => "application/json" })

    # Stub V4 transaction creation (single call with embedded items+tenders)
    stub_request(:post, "#{base_url}/Transaction")
      .to_return do
        {
          status: 201,
          body: {
            "Id" => rand(1000..9999),
            "ServiceType" => 0,
            "TransactionItems" => [{ "Id" => rand(100..999), "ProductId" => 1 }],
            "Tenders" => [{ "TenderTypeId" => 1, "Amount" => 10.00 }]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        }
      end
  end

  describe "#generate_today" do
    it "generates the specified number of orders" do
      orders = generator.generate_today(count: 3)
      expect(orders.size).to eq(3)
    end

    it "each order has V4 fields (Id, TransactionItems, Tenders)" do
      orders = generator.generate_today(count: 1)
      order = orders.first

      expect(order).to include("Id")
      expect(order).to include("TransactionItems")
      expect(order).to include("Tenders")
    end

    it "generates without count using day-of-week pattern" do
      orders = generator.generate_today
      expect(orders.size).to be_between(40, 120)
    end

    it "processes refunds when refund_percentage is positive" do
      gen = described_class.new(refund_percentage: 100)
      orders = gen.generate_today(count: 3)
      expect(orders).not_to be_empty
    end

    it "generates summary when DB connected" do
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(EposNowSandboxSimulator::Models::DailySummary).to receive(:generate_for!).and_return(true)
      allow(EposNowSandboxSimulator::Models::SimulatedOrder).to receive(:create!).and_return(
        double("order", id: "abc")
      )
      allow(EposNowSandboxSimulator::Models::SimulatedPayment).to receive(:create!)

      orders = generator.generate_today(count: 1)
      expect(orders).not_to be_empty
    end

    it "handles summary generation failure gracefully" do
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(EposNowSandboxSimulator::Models::DailySummary).to receive(:generate_for!)
        .and_raise(StandardError, "summary error")
      allow(EposNowSandboxSimulator::Models::SimulatedOrder).to receive(:create!).and_return(
        double("order", id: "abc")
      )
      allow(EposNowSandboxSimulator::Models::SimulatedPayment).to receive(:create!)

      expect { generator.generate_today(count: 1) }.not_to raise_error
    end
  end

  describe "#generate_realistic_day" do
    it "uses multiplier for volume" do
      orders = generator.generate_realistic_day(multiplier: 0.1)
      expect(orders.size).to be_between(1, 20)
    end
  end

  describe "#generate_rush" do
    it "generates orders for a specific period" do
      orders = generator.generate_rush(period: :lunch, count: 5)
      expect(orders.size).to eq(5)
    end

    it "generates dinner rush" do
      orders = generator.generate_rush(period: :dinner, count: 3)
      expect(orders.size).to eq(3)
    end

    it "generates breakfast rush" do
      orders = generator.generate_rush(period: :breakfast, count: 2)
      expect(orders.size).to eq(2)
    end

    it "generates happy_hour rush" do
      orders = generator.generate_rush(period: :happy_hour, count: 2)
      expect(orders.size).to eq(2)
    end

    it "generates late_night rush" do
      orders = generator.generate_rush(period: :late_night, count: 2)
      expect(orders.size).to eq(2)
    end
  end

  describe "meal period distribution" do
    it "distributes orders across periods" do
      distribution = generator.send(:distribute_across_periods, 100)

      expect(distribution.values.sum).to eq(100)
      expect(distribution[:dinner]).to be > distribution[:late_night]
      expect(distribution[:lunch]).to be > distribution[:breakfast]
    end

    it "handles small counts" do
      distribution = generator.send(:distribute_across_periods, 5)
      expect(distribution.values.sum).to eq(5)
    end

    it "adjusts dinner count when rounding does not match total" do
      distribution = generator.send(:distribute_across_periods, 7)
      expect(distribution.values.sum).to eq(7)
    end
  end

  describe "weighted selection" do
    it "selects from weighted options" do
      weights = { a: 90, b: 10 }
      results = 100.times.map { generator.send(:weighted_select, weights) }

      expect(results.count(:a)).to be > 50
    end

    it "always returns a valid key" do
      weights = { a: 1, b: 1, c: 1 }
      100.times do
        result = generator.send(:weighted_select, weights)
        expect(result).to be_in(%i[a b c])
      end
    end

    it "returns last key as fallback" do
      weights = { only: 0 }
      result = generator.send(:weighted_select, weights)
      expect(result).to eq(:only)
    end
  end

  describe "discount calculation" do
    it "returns 0 most of the time (92% chance)" do
      results = 1000.times.map { generator.send(:calculate_discount, 100.0) }
      zero_count = results.count(0.0)
      expect(zero_count).to be_between(850, 1000)
    end

    it "calculates discount between 10-20% when applied" do
      results = 1000.times.map { generator.send(:calculate_discount, 100.0) }.reject(&:zero?)
      expect(results).to all(be_between(10.0, 20.0))
    end
  end

  describe "tip calculation" do
    it "calculates tips for eat_in" do
      tips = 100.times.map { generator.send(:calculate_tip, 50.0, :eat_in) }
      expect(tips.any? { |t| t > 0 }).to be true
    end

    it "calculates tips for takeaway (lower chance)" do
      tips = 100.times.map { generator.send(:calculate_tip, 50.0, :takeaway) }
      zero_count = tips.count(0.0)
      expect(zero_count).to be > 30
    end

    it "calculates tips for delivery" do
      tips = 100.times.map { generator.send(:calculate_tip, 50.0, :delivery) }
      expect(tips.any? { |t| t > 0 }).to be true
    end

    it "uses default tip chance for unknown dining option" do
      tips = 100.times.map { generator.send(:calculate_tip, 50.0, :unknown) }
      expect(tips).to all(be >= 0)
    end
  end

  describe "tender selection" do
    it "selects based on weighted config" do
      tenders_config = [
        { "name" => "cash", "weight" => 50 },
        { "name" => "credit card", "weight" => 50 }
      ]
      result = generator.send(:select_tender, sample_tender_types, tenders_config)
      expect(result).to be_in(sample_tender_types)
    end

    it "returns first tender when no matches" do
      result = generator.send(:select_tender, sample_tender_types, [{ "name" => "bitcoin", "weight" => 100 }])
      expect(result).to eq(sample_tender_types.first)
    end

    it "returns first tender when config is empty" do
      result = generator.send(:select_tender, sample_tender_types, [])
      expect(result).to eq(sample_tender_types.first)
    end
  end

  describe "daily order count" do
    it "returns count within day-of-week range" do
      count = generator.send(:daily_order_count)
      expect(count).to be_between(40, 120)
    end
  end

  describe "fetch_required_data" do
    it "raises when no products found" do
      stub_request(:get, "#{base_url}/Product?page=1")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      expect { generator.send(:fetch_required_data) }.to raise_error(EposNowSandboxSimulator::Error, /No products/)
    end

    it "raises when no tender types found" do
      stub_request(:get, "#{base_url}/TenderType?page=1")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      expect { generator.send(:fetch_required_data) }.to raise_error(EposNowSandboxSimulator::Error, /No tender/)
    end
  end

  describe "persist_order" do
    it "creates SimulatedOrder and SimulatedPayment" do
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)
      order_double = double("order", id: "uuid-1")
      allow(EposNowSandboxSimulator::Models::SimulatedOrder).to receive(:create!).and_return(order_double)
      allow(EposNowSandboxSimulator::Models::SimulatedPayment).to receive(:create!)

      result = { "Id" => 42, "TransactionItems" => [{ "Id" => 1 }], "Tenders" => [{ "Id" => 10 }] }
      generator.send(:persist_order, result, :lunch, :eat_in, 20.0, 1.65, 3.0, 0.0, 24.65, sample_tender_types.first)

      expect(EposNowSandboxSimulator::Models::SimulatedOrder).to have_received(:create!)
      expect(EposNowSandboxSimulator::Models::SimulatedPayment).to have_received(:create!)
    end

    it "handles persistence errors gracefully" do
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(EposNowSandboxSimulator::Models::SimulatedOrder).to receive(:create!)
        .and_raise(StandardError, "db error")

      result = { "Id" => 42, "TransactionItems" => [], "Tenders" => [] }
      expect do
        generator.send(:persist_order, result, :lunch, :eat_in, 20.0, 1.65, 0.0, 0.0, 21.65, sample_tender_types.first)
      end.not_to raise_error
    end
  end

  describe "refund processing" do
    let(:generator_with_refunds) { described_class.new(refund_percentage: 50) }

    before do
      stub_request(:get, "#{base_url}/Product?page=1")
        .to_return(status: 200, body: sample_products.to_json, headers: { "Content-Type" => "application/json" })
      stub_request(:get, "#{base_url}/TenderType?page=1")
        .to_return(status: 200, body: sample_tender_types.to_json, headers: { "Content-Type" => "application/json" })
      stub_request(:post, "#{base_url}/Transaction")
        .to_return do
          { status: 201, body: { "Id" => rand(1000..9999), "TransactionItems" => [], "Tenders" => [] }.to_json,
            headers: { "Content-Type" => "application/json" } }
        end
    end

    it "processes refunds on generated orders" do
      expect { generator_with_refunds.generate_today(count: 4) }.not_to raise_error
    end

    it "updates DB records when connected" do
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)
      simulated_double = double("SimulatedOrder")
      allow(simulated_double).to receive(:update!)
      allow(EposNowSandboxSimulator::Models::SimulatedOrder).to receive_messages(find_by: simulated_double,
                                                                                 create!: double(
                                                                                   "order", id: "x"
                                                                                 ))
      allow(EposNowSandboxSimulator::Models::SimulatedPayment).to receive(:create!)
      allow(EposNowSandboxSimulator::Models::DailySummary).to receive(:generate_for!)

      generator_with_refunds.generate_today(count: 2)
      expect(EposNowSandboxSimulator::Models::SimulatedOrder).to have_received(:find_by).at_least(:once)
    end

    it "skips orders without transaction_id" do
      gen = described_class.new(refund_percentage: 100)
      orders = [{ "Id" => nil }]
      gen.send(:process_refunds, orders)
    end

    it "handles SimulatedOrder not found in DB" do
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(EposNowSandboxSimulator::Models::SimulatedOrder).to receive(:find_by).and_return(nil)

      gen = described_class.new(refund_percentage: 100)
      orders = [{ "Id" => 123 }]
      expect { gen.send(:process_refunds, orders) }.not_to raise_error
    end

    it "handles empty orders array" do
      expect { generator.send(:process_refunds, []) }.not_to raise_error
    end

    it "skips processing when refund_count is zero" do
      zero_refund_gen = described_class.new(refund_percentage: 0)
      orders = [{ "Id" => 1 }, { "Id" => 2 }]
      # Should not attempt any refunds
      zero_refund_gen.send(:process_refunds, orders)
    end
  end

  describe "generate_single_order error handling" do
    it "returns nil when products list is empty" do
      data = { products: [], tender_types: sample_tender_types, tenders_config: [] }
      result = generator.send(:generate_single_order, data, period: :lunch)
      expect(result).to be_nil
    end

    it "returns nil on API failure" do
      stub_request(:post, "#{base_url}/Transaction")
        .to_return(status: 500, body: { "message" => "error" }.to_json, headers: { "Content-Type" => "application/json" })

      data = { products: sample_products, tender_types: sample_tender_types, tenders_config: [] }
      result = generator.send(:generate_single_order, data, period: :lunch)
      expect(result).to be_nil
    end
  end

  describe "persist_order with nil tender data" do
    it "handles nil Tenders in result" do
      allow(EposNowSandboxSimulator::Database).to receive(:connected?).and_return(true)
      order_double = double("order", id: "uuid-1")
      allow(EposNowSandboxSimulator::Models::SimulatedOrder).to receive(:create!).and_return(order_double)
      allow(EposNowSandboxSimulator::Models::SimulatedPayment).to receive(:create!)

      tender_type = { "Id" => 1, "Name" => nil }
      result = { "Id" => 42, "TransactionItems" => nil, "Tenders" => nil }
      generator.send(:persist_order, result, :lunch, :eat_in, 20.0, 1.65, 0.0, 0.0, 21.65, tender_type)

      expect(EposNowSandboxSimulator::Models::SimulatedPayment).to have_received(:create!)
    end
  end

  describe "select_tender with nil name matching" do
    it "handles tender types with nil Name" do
      tender_types_with_nil = [{ "Id" => 1, "Name" => nil }, { "Id" => 2, "Name" => "Cash" }]
      tenders_config = [{ "name" => "cash", "weight" => 100 }]
      result = generator.send(:select_tender, tender_types_with_nil, tenders_config)
      expect(result["Id"]).to eq(2)
    end

    it "handles tenders_config with nil name" do
      tenders_config = [{ "name" => nil, "weight" => 100 }]
      result = generator.send(:select_tender, sample_tender_types, tenders_config)
      expect(result).to eq(sample_tender_types.first)
    end
  end
end
