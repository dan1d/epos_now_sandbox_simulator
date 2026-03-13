# frozen_string_literal: true

require "spec_helper"

RSpec.describe EposNowSandboxSimulator::Database do
  describe ".test_database_url" do
    it "returns default test URL when no base URL" do
      url = described_class.test_database_url
      expect(url).to include("epos_now_simulator_test")
    end

    it "replaces database name in provided URL" do
      url = described_class.test_database_url(base_url: "postgres://localhost:5432/mydb")
      expect(url).to eq("postgres://localhost:5432/epos_now_simulator_test")
    end

    it "handles invalid URI gracefully" do
      url = described_class.test_database_url(base_url: "not a url")
      expect(url).to include("epos_now_simulator_test")
    end
  end

  describe ".connected?" do
    it "returns false when not connected" do
      expect(described_class.connected?).to be false
    end
  end

  describe "MIGRATIONS_PATH" do
    it "points to a valid directory" do
      expect(File.directory?(described_class::MIGRATIONS_PATH)).to be true
    end
  end

  describe "TEST_DATABASE" do
    it "is epos_now_simulator_test" do
      expect(described_class::TEST_DATABASE).to eq("epos_now_simulator_test")
    end
  end

  describe ".create!" do
    it "creates a database" do
      connection_double = double("connection")
      allow(ActiveRecord::Base).to receive(:establish_connection)
      allow(connection_double).to receive(:create_database)
      pool_double = instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool)
      allow(ActiveRecord::Base).to receive_messages(connection: connection_double, connection_pool: pool_double)
      allow(pool_double).to receive(:disconnect!)

      expect { described_class.create!("postgres://localhost:5432/testdb") }.not_to raise_error
    end

    it "handles database already exists error" do
      connection_double = double("connection")
      allow(ActiveRecord::Base).to receive(:establish_connection)
      allow(connection_double).to receive(:create_database).and_raise(
        ActiveRecord::StatementInvalid.new("database \"testdb\" already exists")
      )
      pool_double = instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool)
      allow(ActiveRecord::Base).to receive_messages(connection: connection_double, connection_pool: pool_double)
      allow(pool_double).to receive(:disconnect!)

      expect { described_class.create!("postgres://localhost:5432/testdb") }.not_to raise_error
    end

    it "re-raises non-already-exists errors" do
      connection_double = double("connection")
      allow(ActiveRecord::Base).to receive(:establish_connection)
      allow(connection_double).to receive(:create_database).and_raise(
        ActiveRecord::StatementInvalid.new("permission denied")
      )
      pool_double = instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool)
      allow(ActiveRecord::Base).to receive_messages(connection: connection_double, connection_pool: pool_double)
      allow(pool_double).to receive(:disconnect!)

      expect { described_class.create!("postgres://localhost:5432/testdb") }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe ".drop!" do
    it "drops a database" do
      connection_double = double("connection")
      allow(ActiveRecord::Base).to receive(:establish_connection)
      allow(connection_double).to receive(:drop_database)
      pool_double = instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool)
      allow(ActiveRecord::Base).to receive_messages(connection: connection_double, connection_pool: pool_double)
      allow(pool_double).to receive(:disconnect!)

      expect { described_class.drop!("postgres://localhost:5432/testdb") }.not_to raise_error
    end

    it "handles database does not exist error" do
      connection_double = double("connection")
      allow(ActiveRecord::Base).to receive(:establish_connection)
      allow(connection_double).to receive(:drop_database).and_raise(
        ActiveRecord::StatementInvalid.new("database \"testdb\" does not exist")
      )
      pool_double = instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool)
      allow(ActiveRecord::Base).to receive_messages(connection: connection_double, connection_pool: pool_double)
      allow(pool_double).to receive(:disconnect!)

      expect { described_class.drop!("postgres://localhost:5432/testdb") }.not_to raise_error
    end

    it "re-raises non-does-not-exist errors" do
      connection_double = double("connection")
      allow(ActiveRecord::Base).to receive(:establish_connection)
      allow(connection_double).to receive(:drop_database).and_raise(
        ActiveRecord::StatementInvalid.new("permission denied")
      )
      pool_double = instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool)
      allow(ActiveRecord::Base).to receive_messages(connection: connection_double, connection_pool: pool_double)
      allow(pool_double).to receive(:disconnect!)

      expect { described_class.drop!("postgres://localhost:5432/testdb") }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe ".database_url" do
    it "returns URL from .env.json" do
      allow(EposNowSandboxSimulator::Configuration).to receive(:database_url_from_file)
        .and_return("postgres://localhost:5432/epos_now_dev")
      expect(described_class.database_url).to eq("postgres://localhost:5432/epos_now_dev")
    end

    it "raises when no DATABASE_URL found" do
      allow(EposNowSandboxSimulator::Configuration).to receive(:database_url_from_file).and_return(nil)
      expect { described_class.database_url }.to raise_error(EposNowSandboxSimulator::Error, /DATABASE_URL/)
    end
  end

  describe ".connect!" do
    it "establishes ActiveRecord connection" do
      connection_double = double("connection")
      allow(ActiveRecord::Base).to receive(:establish_connection)
      allow(ActiveRecord::Base).to receive(:connection).and_return(connection_double)
      allow(connection_double).to receive(:execute).with("SELECT 1")
      allow(ActiveRecord::Base).to receive(:logger=)

      expect { described_class.connect!("postgres://localhost:5432/testdb") }.not_to raise_error
    end

    it "rejects non-PostgreSQL URLs" do
      expect { described_class.connect!("mysql://localhost/testdb") }.to raise_error(ArgumentError, /PostgreSQL/)
    end

    it "accepts postgresql:// scheme" do
      connection_double = double("connection")
      allow(ActiveRecord::Base).to receive(:establish_connection)
      allow(ActiveRecord::Base).to receive(:connection).and_return(connection_double)
      allow(connection_double).to receive(:execute).with("SELECT 1")
      allow(ActiveRecord::Base).to receive(:logger=)

      expect { described_class.connect!("postgresql://localhost:5432/testdb") }.not_to raise_error
    end
  end

  describe ".migrate!" do
    it "raises when not connected" do
      allow(described_class).to receive(:connected?).and_return(false)
      expect { described_class.migrate! }.to raise_error(EposNowSandboxSimulator::Error, /not connected/)
    end

    it "runs migrations when connected" do
      allow(described_class).to receive(:connected?).and_return(true)
      context_double = instance_double(ActiveRecord::MigrationContext)
      allow(ActiveRecord::MigrationContext).to receive(:new).and_return(context_double)
      allow(context_double).to receive(:migrate)

      expect { described_class.migrate! }.not_to raise_error
    end
  end

  describe ".seed!" do
    it "raises when not connected" do
      allow(described_class).to receive(:connected?).and_return(false)
      expect { described_class.seed! }.to raise_error(EposNowSandboxSimulator::Error, /not connected/)
    end

    it "calls Seeder.seed! when connected" do
      allow(described_class).to receive(:connected?).and_return(true)
      allow(described_class).to receive(:load_factories!)
      allow(EposNowSandboxSimulator::Seeder).to receive(:seed!).and_return({ business_types: 1 })

      described_class.seed!(business_type: :restaurant)
      expect(EposNowSandboxSimulator::Seeder).to have_received(:seed!).with(business_type: :restaurant)
    end

    it "defaults to configured business_type" do
      allow(described_class).to receive(:connected?).and_return(true)
      allow(described_class).to receive(:load_factories!)
      allow(EposNowSandboxSimulator::Seeder).to receive(:seed!).and_return({})

      described_class.seed!
      expect(EposNowSandboxSimulator::Seeder).to have_received(:seed!).with(business_type: :restaurant)
    end
  end

  describe ".disconnect!" do
    it "disconnects the connection pool" do
      pool_double = instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool)
      allow(ActiveRecord::Base).to receive(:connection_pool).and_return(pool_double)
      allow(pool_double).to receive(:disconnect!)

      expect { described_class.disconnect! }.not_to raise_error
    end
  end

  describe "private .sanitize_url" do
    it "masks username and password" do
      url = described_class.send(:sanitize_url, "postgres://user:pass@localhost:5432/db")
      expect(url).to include("***")
      expect(url).not_to include("user")
      expect(url).not_to include("pass")
    end

    it "masks only username when no password" do
      url = described_class.send(:sanitize_url, "postgres://user@localhost:5432/db")
      expect(url).to include("***")
      expect(url).not_to include("user")
    end

    it "handles URL without credentials" do
      url = described_class.send(:sanitize_url, "postgres://localhost:5432/db")
      expect(url).to include("localhost")
    end

    it "handles invalid URI with regex fallback" do
      url = described_class.send(:sanitize_url, "postgres://user:pass@loc alhost/db")
      expect(url).to include("***")
    end
  end

  describe "private .load_factories!" do
    it "loads FactoryBot definitions" do
      # Reset the loaded flag
      described_class.instance_variable_set(:@factories_loaded, false)
      allow(Dir).to receive(:exist?).and_call_original
      allow(FactoryBot).to receive(:definition_file_paths=)
      allow(FactoryBot).to receive(:find_definitions)

      described_class.send(:load_factories!)
      expect(described_class.instance_variable_get(:@factories_loaded)).to be true
    end

    it "skips if already loaded" do
      described_class.instance_variable_set(:@factories_loaded, true)
      allow(FactoryBot).to receive(:find_definitions)
      described_class.send(:load_factories!)
      expect(FactoryBot).not_to have_received(:find_definitions)
    end

    it "handles load errors gracefully" do
      described_class.instance_variable_set(:@factories_loaded, false)
      allow(FactoryBot).to receive(:definition_file_paths=).and_raise(StandardError, "load error")

      expect { described_class.send(:load_factories!) }.not_to raise_error
    end

    it "skips setting definition_file_paths when factories dir does not exist" do
      described_class.instance_variable_set(:@factories_loaded, false)
      allow(Dir).to receive(:exist?).and_call_original
      allow(Dir).to receive(:exist?).with(anything).and_return(false)
      allow(FactoryBot).to receive(:find_definitions)

      described_class.send(:load_factories!)
      expect(FactoryBot).to have_received(:find_definitions)
    end
  end
end
