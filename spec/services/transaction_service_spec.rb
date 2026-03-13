# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Services::EposNow::TransactionService do
  let(:service) { described_class.new }
  let(:base_url) { "https://api.eposnowhq.com/api/v4" }

  describe "#create_transaction" do
    it "creates a transaction with embedded items and tenders" do
      response = {
        "Id" => 100,
        "ServiceType" => 0,
        "Gratuity" => 5.00,
        "TransactionItems" => [{ "Id" => 1, "ProductId" => 10, "Quantity" => 1 }],
        "Tenders" => [{ "TenderTypeId" => 1, "Amount" => 25.00 }]
      }

      stub_request(:post, "#{base_url}/Transaction")
        .with do |req|
          body = JSON.parse(req.body)
          body["ServiceType"] == 0 &&
            body["TransactionItems"].any? { |i| i["ProductId"] == 10 && i["Quantity"] == 1 } &&
            body["Tenders"].any? { |t| t["TenderTypeId"] == 1 && (t["Amount"] - 25.0).abs < 0.001 }
        end
        .to_return(status: 201, body: response.to_json, headers: { "Content-Type" => "application/json" })

      result = service.create_transaction(
        items: [{ product_id: 10, quantity: 1 }],
        tenders: [{ tender_type_id: 1, amount: 25.00 }]
      )

      expect(result["Id"]).to eq(100)
      expect(result["TransactionItems"].size).to eq(1)
      expect(result["Tenders"].size).to eq(1)
    end

    it "creates a takeaway transaction" do
      stub_request(:post, "#{base_url}/Transaction")
        .with(body: hash_including("ServiceType" => 1))
        .to_return(status: 201, body: { "Id" => 101, "ServiceType" => 1 }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.create_transaction(
        items: [{ product_id: 1, quantity: 1 }],
        tenders: [{ tender_type_id: 1, amount: 10.00 }],
        service_type: 1
      )
      expect(result["ServiceType"]).to eq(1)
    end

    it "creates a delivery transaction with gratuity" do
      stub_request(:post, "#{base_url}/Transaction")
        .with(body: hash_including("ServiceType" => 2, "Gratuity" => 3.50))
        .to_return(status: 201, body: { "Id" => 102, "ServiceType" => 2,
                                        "Gratuity" => 3.50 }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.create_transaction(
        items: [{ product_id: 1, quantity: 1 }],
        tenders: [{ tender_type_id: 1, amount: 20.00 }],
        service_type: 2,
        gratuity: 3.50
      )
      expect(result["Gratuity"]).to eq(3.50)
    end

    it "includes discount_value and service_charge" do
      stub_request(:post, "#{base_url}/Transaction")
        .with(body: hash_including("DiscountValue" => 5.00, "ServiceCharge" => 2.00))
        .to_return(status: 201, body: { "Id" => 103 }.to_json, headers: { "Content-Type" => "application/json" })

      service.create_transaction(
        items: [{ product_id: 1, quantity: 1 }],
        tenders: [{ tender_type_id: 1, amount: 20.00 }],
        discount_value: 5.00,
        service_charge: 2.00
      )
    end

    it "includes optional staff_id and customer_id" do
      stub_request(:post, "#{base_url}/Transaction")
        .with(body: hash_including("StaffId" => 5, "CustomerId" => 10))
        .to_return(status: 201, body: { "Id" => 104 }.to_json, headers: { "Content-Type" => "application/json" })

      service.create_transaction(
        items: [{ product_id: 1, quantity: 1 }],
        tenders: [{ tender_type_id: 1, amount: 10.00 }],
        staff_id: 5,
        customer_id: 10
      )
    end
  end

  describe "#fetch_transactions" do
    it "fetches transactions by page" do
      transactions = [{ "Id" => 1 }, { "Id" => 2 }]

      stub_request(:get, "#{base_url}/Transaction?page=1")
        .to_return(status: 200, body: transactions.to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_transactions(page: 1)
      expect(result.size).to eq(2)
    end

    it "fetches all transactions across pages" do
      stub_request(:get, "#{base_url}/Transaction?page=1")
        .to_return(status: 200, body: [{ "Id" => 1 }].to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_transactions
      expect(result.size).to eq(1)
    end

    it "passes status filter when provided" do
      stub_request(:get, "#{base_url}/Transaction?page=1&status=1")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_transactions(page: 1, status: 1)
      expect(result).to eq([])
    end
  end

  describe "#fetch_transactions_by_date" do
    it "fetches transactions for a date range" do
      transactions = [{ "Id" => 10, "DateTime" => "2026-03-13T12:00:00" }]

      stub_request(:get, %r{#{base_url}/Transaction/GetByDate})
        .to_return(status: 200, body: transactions.to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_transactions_by_date(
        start_date: "2026-03-13",
        end_date: "2026-03-13"
      )
      expect(result.size).to eq(1)
    end

    it "passes device_id and status filters" do
      stub_request(:get, %r{#{base_url}/Transaction/GetByDate.*deviceId=5.*status=1})
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_transactions_by_date(
        start_date: "2026-03-13",
        end_date: "2026-03-13",
        device_id: 5,
        status: 1
      )
      expect(result).to eq([])
    end
  end

  describe "#fetch_transactions_by_date pagination" do
    it "paginates through multiple pages of date results" do
      page1 = (1..200).map { |i| { "Id" => i } }
      page2 = [{ "Id" => 201 }]

      stub_request(:get, %r{#{base_url}/Transaction/GetByDate.*page=1})
        .to_return(status: 200, body: page1.to_json, headers: { "Content-Type" => "application/json" })
      stub_request(:get, %r{#{base_url}/Transaction/GetByDate.*page=2})
        .to_return(status: 200, body: page2.to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_transactions_by_date(start_date: "2026-03-13", end_date: "2026-03-14")
      expect(result.size).to eq(201)
    end

    it "handles non-array response from GetByDate" do
      stub_request(:get, %r{#{base_url}/Transaction/GetByDate})
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_transactions_by_date(start_date: "2026-03-13", end_date: "2026-03-13")
      expect(result).to eq([])
    end
  end

  describe "#fetch_latest_transactions" do
    it "fetches latest transactions" do
      stub_request(:get, "#{base_url}/Transaction/GetLatest")
        .to_return(status: 200, body: [{ "Id" => 99 }].to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_latest_transactions
      expect(result.first["Id"]).to eq(99)
    end

    it "passes device_id and status filters" do
      stub_request(:get, %r{#{base_url}/Transaction/GetLatest\?deviceId=3&status=2})
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      result = service.fetch_latest_transactions(device_id: 3, status: 2)
      expect(result).to eq([])
    end
  end

  describe "#get_transaction" do
    it "fetches a transaction by ID without lock" do
      stub_request(:get, "#{base_url}/Transaction/100/false")
        .to_return(status: 200, body: { "Id" => 100 }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.get_transaction(100)
      expect(result["Id"]).to eq(100)
    end

    it "fetches a transaction with lock" do
      stub_request(:get, "#{base_url}/Transaction/100/true")
        .to_return(status: 200, body: { "Id" => 100 }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.get_transaction(100, lock: true)
      expect(result["Id"]).to eq(100)
    end
  end

  describe "#delete_transaction" do
    it "deletes a transaction by ID" do
      stub_request(:delete, "#{base_url}/Transaction/100")
        .to_return(status: 204, body: "", headers: {})

      expect { service.delete_transaction(100) }.not_to raise_error
    end
  end

  describe "#validate_transaction" do
    it "validates a transaction payload without saving" do
      payload = { "ServiceType" => 0, "TransactionItems" => [{ "ProductId" => 1 }] }

      stub_request(:post, "#{base_url}/Transaction/Validate")
        .to_return(status: 200, body: { "IsValid" => true }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.validate_transaction(payload)
      expect(result["IsValid"]).to be true
    end
  end

  describe "constants" do
    it "defines EAT_IN as 0" do
      expect(described_class::EAT_IN).to eq(0)
    end

    it "defines TAKEAWAY as 1" do
      expect(described_class::TAKEAWAY).to eq(1)
    end

    it "defines DELIVERY as 2" do
      expect(described_class::DELIVERY).to eq(2)
    end
  end

  describe "#create_transaction with optional item fields" do
    it "includes unit_price, discount, and notes" do
      stub_request(:post, "#{base_url}/Transaction")
        .with do |req|
          body = JSON.parse(req.body)
          item = body["TransactionItems"].first
          (item["UnitPrice"] - 9.99).abs < 0.001 &&
            (item["DiscountAmount"] - 2.0).abs < 0.001 &&
            item["Notes"] == "Extra sauce"
        end
        .to_return(status: 201, body: { "Id" => 200 }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.create_transaction(
        items: [{ product_id: 1, quantity: 2, unit_price: 9.99, discount: 2.0, notes: "Extra sauce" }],
        tenders: [{ tender_type_id: 1, amount: 17.98 }]
      )
      expect(result["Id"]).to eq(200)
    end

    it "omits zero discount" do
      stub_request(:post, "#{base_url}/Transaction")
        .with do |req|
          body = JSON.parse(req.body)
          !body["TransactionItems"].first.key?("DiscountAmount")
        end
        .to_return(status: 201, body: { "Id" => 201 }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.create_transaction(
        items: [{ product_id: 1, quantity: 1, discount: 0.0 }],
        tenders: [{ tender_type_id: 1, amount: 10.0 }]
      )
      expect(result["Id"]).to eq(201)
    end

    it "includes change_given for tenders" do
      stub_request(:post, "#{base_url}/Transaction")
        .with do |req|
          body = JSON.parse(req.body)
          (body["Tenders"].first["ChangeGiven"] - 5.0).abs < 0.001
        end
        .to_return(status: 201, body: { "Id" => 202 }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.create_transaction(
        items: [{ product_id: 1, quantity: 1 }],
        tenders: [{ tender_type_id: 1, amount: 20.0, change_given: 5.0 }]
      )
      expect(result["Id"]).to eq(202)
    end
  end
end
