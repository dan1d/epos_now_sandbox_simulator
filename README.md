# Epos Now Sandbox Simulator

A Ruby gem for simulating Point of Sale operations against the **Epos Now V4 REST API**. Generates realistic restaurant, cafe, bar, and retail orders with payments and transaction data for testing integrations.

## Features

- **4 Business Types**: Restaurant, Cafe/Bakery, Bar/Nightclub, Retail General — each with tailored categories and items
- **84 Menu/Product Items**: Spread across 20 categories with realistic pricing
- **V4 Transactions**: Single POST with embedded `TransactionItems[]` and `Tenders[]`
- **Basic Auth**: API Key + Secret authentication (no OAuth, no token refresh)
- **Meal Period Simulation**: Orders distributed across breakfast, lunch, happy hour, dinner, and late night
- **Order Types**: Eat-in (`ServiceType: 0`), Takeaway (`1`), and Delivery (`2`)
- **Dynamic Order Volume**: 40–120 orders/day based on day of week
- **Tips & Taxes**: Variable tip rates by dining option (15–25% eat-in, 0–15% takeaway, 10–20% delivery)
- **Discounts**: 10–20% applied probabilistically (8% chance per order)
- **Multiple Payment Methods**: Cash, Credit Card, Debit Card, Gift Card, Mobile Pay — weighted selection
- **PostgreSQL Audit Trail**: Track all simulated orders, payments, and API requests
- **Daily Summaries**: Automated aggregation of revenue, tax, tips, and discounts by meal period and tender
- **Multi-Device Support**: Configure multiple API devices via `.env.json`
- **Database Seeding**: Idempotent FactoryBot-based seeder for all 4 business types

## Installation

Add to your Gemfile:

```ruby
gem "epos_now_sandbox_simulator"
```

Then:

```bash
bundle install
```

Or install directly:

```bash
gem install epos_now_sandbox_simulator
```

## Configuration

### Getting API Credentials

1. Log in to your **Epos Now Backoffice** at https://eposnowhq.com
2. Register an **API Device** under Settings
3. Copy the **API Key** and **API Secret**
4. The auth token is `Base64(api_key:api_secret)` — the simulator handles this automatically

### Multi-Device Setup (Recommended)

Create a `.env.json` file:

```json
{
  "DATABASE_URL": "postgres://localhost:5432/epos_now_simulator_development",
  "merchants": [
    {
      "EPOS_NOW_API_KEY": "your-api-key",
      "EPOS_NOW_API_SECRET": "your-api-secret",
      "EPOS_NOW_DEVICE_NAME": "Restaurant Device"
    },
    {
      "EPOS_NOW_API_KEY": "second-device-key",
      "EPOS_NOW_API_SECRET": "second-device-secret",
      "EPOS_NOW_DEVICE_NAME": "Cafe Device"
    }
  ]
}
```

### Single Device Setup

Use a `.env` file:

```env
EPOS_NOW_API_KEY=your-api-key
EPOS_NOW_API_SECRET=your-api-secret
EPOS_NOW_BASE_URL=https://api.eposnowhq.com
LOG_LEVEL=INFO
TAX_RATE=20.0
```

### Database Setup

The simulator uses PostgreSQL to persist audit data (simulated orders, payments, API requests, daily summaries):

```bash
./bin/simulate db create
./bin/simulate db migrate
./bin/simulate db seed
```

## Usage

### Quick Start

```bash
# Full setup + order generation in one command
./bin/simulate full
```

### Commands

```bash
# Show version
./bin/simulate version

# List configured API devices
./bin/simulate merchants

# Set up POS entities (categories, products, tender types)
./bin/simulate setup

# Generate orders for today (random count based on day of week)
./bin/simulate generate

# Generate a specific number of orders
./bin/simulate generate -n 25

# Generate orders with refunds (5% of orders refunded)
./bin/simulate generate -n 25 -r 10

# Generate a realistic full day of operations
./bin/simulate day

# Busy day (2x normal volume)
./bin/simulate day -x 2.0

# Slow day (half volume)
./bin/simulate day -x 0.5

# Generate a lunch or dinner rush
./bin/simulate rush -p lunch -n 20
./bin/simulate rush -p dinner -n 30

# Check current entity counts
./bin/simulate status

# Use a specific device by index
./bin/simulate setup -i 0
./bin/simulate generate -i 1 -n 20

# List available business types
./bin/simulate business_types
```

### Database Management

```bash
./bin/simulate db create    # Create PostgreSQL database
./bin/simulate db migrate   # Run pending migrations
./bin/simulate db seed      # Seed business types, categories, items
./bin/simulate db reset     # Drop, create, migrate, and seed

# Reporting
./bin/simulate summary      # Show daily summary
./bin/simulate audit        # Show recent API requests
```

## Business Types

| Type | Categories | Items | Description |
|------|-----------|-------|-------------|
| `restaurant` | 5 | 25 | Full-service casual dining |
| `cafe_bakery` | 5 | 24 | Coffee shop with pastries and light fare |
| `bar_nightclub` | 5 | 22 | Craft cocktails, draft beer, late-night bites |
| `retail_general` | 5 | 13 | Electronics, home goods, personal care |

## Epos Now V4 API Endpoints

| Endpoint | Operations |
|----------|-----------|
| `/api/v4/Category` | CRUD for product categories |
| `/api/v4/Product` | CRUD for products/items |
| `/api/v4/TenderType` | CRUD for payment method types |
| `/api/v4/Transaction` | Create with embedded items + tenders |
| `/api/v4/Transaction/GetByDate` | Fetch transactions by date range |
| `/api/v4/Transaction/GetLatest` | Fetch most recent transactions |
| `/api/v4/Transaction/Validate` | Validate a transaction before commit |
| `/api/v4/TaxGroup` | Tax group and rate management |

### Key Differences from Clover/Square

| Feature | Epos Now V4 | Clover | Square |
|---------|------------|--------|--------|
| Auth | Basic Auth (static) | OAuth2 Bearer | OAuth2 Bearer |
| Transactions | Single POST with embedded items + tenders | Separate order, line items, payment calls | Single order with line items |
| Order Types | `ServiceType`: 0=EatIn, 1=Takeaway, 2=Delivery | `OrderType` entities | Fulfillment types |
| Pagination | `?page=N` (200/page) | `?offset=N&limit=N` | Cursor-based |
| Delete | Request body `[{Id: int}]` | URL path `/v3/.../ID` | URL path |
| IDs | Integer | UUID-like string | UUID-like string |

## Order Patterns

### Daily Volume

| Day | Min Orders | Max Orders |
|-----|-----------|-----------|
| Weekday | 40 | 60 |
| Friday | 70 | 100 |
| Saturday | 80 | 120 |
| Sunday | 50 | 80 |

### Meal Periods

| Period | Weight | Items | Typical Total |
|--------|--------|-------|--------------|
| Breakfast | 15% | 1–3 | $8–$20 |
| Lunch | 30% | 2–4 | $12–$35 |
| Happy Hour | 10% | 2–4 | $10–$25 |
| Dinner | 35% | 3–6 | $20–$60 |
| Late Night | 10% | 1–3 | $8–$25 |

### Dining Options

| Period | Eat-In | Takeaway | Delivery |
|--------|--------|----------|----------|
| Breakfast | 40% | 50% | 10% |
| Lunch | 35% | 45% | 20% |
| Happy Hour | 80% | 15% | 5% |
| Dinner | 70% | 15% | 15% |
| Late Night | 50% | 30% | 20% |

## Tips

| Dining Option | Tip Chance | Min Tip | Max Tip |
|---------------|-----------|---------|---------|
| Eat-In | 70% | 15% | 25% |
| Takeaway | 20% | 5% | 15% |
| Delivery | 50% | 10% | 20% |

## Audit Trail & Persistence

### Models

| Model | Purpose |
|-------|---------|
| `BusinessType` | 4 business types with category/item associations |
| `Category` | 20 categories linked to business types |
| `Item` | 84 items with SKUs, pricing, and category assignments |
| `SimulatedOrder` | Every generated order with meal period, dining option, amounts |
| `SimulatedPayment` | Payment records with tender type and transaction reference |
| `ApiRequest` | Full audit log of every HTTP call (method, URL, status, duration) |
| `DailySummary` | Daily aggregation of revenue, tax, tips, discounts by period/tender |

## Architecture

```
lib/epos_now_sandbox_simulator/
├── configuration.rb           # Multi-device config, Basic Auth token
├── database.rb                # Standalone ActiveRecord (no Rails)
├── seeder.rb                  # Idempotent DB seeding via FactoryBot
├── data/                      # JSON data files per business type
│   ├── restaurant/
│   ├── cafe_bakery/
│   ├── bar_nightclub/
│   └── retail_general/
├── generators/
│   ├── data_loader.rb         # DB-first with JSON fallback
│   ├── entity_generator.rb    # Setup categories/products/tenders
│   └── order_generator.rb     # Realistic order generation
├── models/                    # ActiveRecord models (standalone)
│   ├── business_type.rb
│   ├── category.rb
│   ├── item.rb
│   ├── simulated_order.rb
│   ├── simulated_payment.rb
│   ├── api_request.rb
│   └── daily_summary.rb
├── services/
│   ├── base_service.rb        # HTTP client, auth, pagination, audit
│   └── epos_now/
│       ├── inventory_service.rb    # Categories + Products
│       ├── tender_service.rb       # Tender types
│       ├── transaction_service.rb  # V4 transactions
│       ├── tax_service.rb          # Tax groups + calculation
│       └── services_manager.rb     # Thread-safe lazy loader
└── db/
    ├── migrate/               # 8 migrations (UUID v7 PKs)
    └── factories/             # FactoryBot for tests + seeding
```

## Development

```bash
# Install dependencies
bundle install

# Run all tests (286 examples)
bundle exec rspec

# Run with coverage report (100% line + branch required)
COVERAGE=true bundle exec rspec

# Run linter (0 offenses required)
bundle exec rubocop

# Run specific test groups
bundle exec rspec spec/services/
bundle exec rspec spec/generators/
bundle exec rspec spec/models/

# Open console
bundle exec irb -r ./lib/epos_now_sandbox_simulator

# Build the gem
gem build epos_now_sandbox_simulator.gemspec
```

### Test Coverage

- **286 examples, 0 failures**
- **100% line coverage** (802/802 lines)
- **100% branch coverage** (223/223 branches)
- **Rubocop: 0 offenses** (52 files)

## Ruby API

```ruby
require "epos_now_sandbox_simulator"

# Configure
config = EposNowSandboxSimulator::Configuration.new
config.api_key = "your-api-key"
config.api_secret = "your-api-secret"

# Use services directly
manager = EposNowSandboxSimulator::Services::EposNow::ServicesManager.new(config: config)

# Inventory
categories = manager.inventory.list_categories
products = manager.inventory.list_products
manager.inventory.create_category(name: "Specials", sort_order: 99)
manager.inventory.create_product(name: "Daily Special", price: 14.99, category_id: 1)

# Transactions
result = manager.transactions.create_transaction(
  service_type: 0, # EatIn
  items: [
    { product_id: 1, quantity: 2, unit_price: 9.99 },
    { product_id: 3, quantity: 1 }
  ],
  tenders: [
    { tender_type_id: 1, amount: 29.97 }
  ]
)

# Fetch transactions by date
transactions = manager.transactions.fetch_by_date(
  start_date: Date.today,
  end_date: Date.today
)

# Tax groups
tax_groups = manager.tax.list_tax_groups

# Generate realistic orders
generator = EposNowSandboxSimulator::Generators::OrderGenerator.new(
  config: config,
  refund_percentage: 5
)
orders = generator.generate_today(count: 25)
```

## Sandbox Limitations

This gem is designed for **sandbox and development environments only** — not for production use. It generates test data against the Epos Now API to validate integrations before going live.

| Feature | Notes |
|---------|-------|
| Authentication | Basic Auth with sandbox API credentials |
| Transactions | Created in sandbox, visible in Epos Now Backoffice |
| Date | Epos Now may restrict orders to current date |
| Rate Limits | Sandbox may have different rate limits than production |

## License

[MIT License](LICENSE)
