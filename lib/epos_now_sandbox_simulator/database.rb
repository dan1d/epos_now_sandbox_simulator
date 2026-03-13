# frozen_string_literal: true

require "active_record"
require "logger"

module EposNowSandboxSimulator
  # Standalone ActiveRecord connection manager for PostgreSQL.
  #
  # Provides database connectivity without requiring Rails.
  # Used for persisting Epos Now sandbox data (orders, payments, etc.)
  # alongside the existing JSON-file and API-based workflows.
  module Database
    MIGRATIONS_PATH = File.expand_path("db/migrate", __dir__).freeze
    TEST_DATABASE = "epos_now_simulator_test"

    class << self
      def create!(url)
        db_name = URI.parse(url).path.delete_prefix("/")
        maintenance_url = url.sub(%r{/[^/]+\z}, "/postgres")

        ActiveRecord::Base.establish_connection(maintenance_url)
        ActiveRecord::Base.connection.create_database(db_name)
        EposNowSandboxSimulator.logger.info("Database created: #{db_name}")
      rescue ActiveRecord::DatabaseAlreadyExists, ActiveRecord::StatementInvalid => e
        raise unless e.message.include?("already exists")

        EposNowSandboxSimulator.logger.info("Database already exists: #{db_name}")
      ensure
        ActiveRecord::Base.connection_pool.disconnect!
      end

      def drop!(url)
        db_name = URI.parse(url).path.delete_prefix("/")
        maintenance_url = url.sub(%r{/[^/]+\z}, "/postgres")

        ActiveRecord::Base.establish_connection(maintenance_url)
        ActiveRecord::Base.connection.drop_database(db_name)
        EposNowSandboxSimulator.logger.info("Database dropped: #{db_name}")
      rescue ActiveRecord::StatementInvalid => e
        raise unless e.message.include?("does not exist")

        EposNowSandboxSimulator.logger.info("Database does not exist: #{db_name}")
      ensure
        ActiveRecord::Base.connection_pool.disconnect!
      end

      def database_url
        url = Configuration.database_url_from_file
        raise Error, "No DATABASE_URL found in .env.json" unless url

        url
      end

      def connect!(url)
        raise ArgumentError, "Expected a PostgreSQL URL, got: #{url.split("://").first}://" unless url.match?(%r{\Apostgres(ql)?://}i)

        ActiveRecord::Base.establish_connection(url)
        ActiveRecord::Base.connection.execute("SELECT 1")
        ActiveRecord::Base.logger = EposNowSandboxSimulator.logger

        EposNowSandboxSimulator.logger.info("Database connected: #{sanitize_url(url)}")
      end

      def migrate!
        ensure_connected!

        EposNowSandboxSimulator.logger.info("Running migrations from #{MIGRATIONS_PATH}")
        context = ActiveRecord::MigrationContext.new(MIGRATIONS_PATH)
        context.migrate
        EposNowSandboxSimulator.logger.info("Migrations complete")
      end

      def seed!(business_type: nil)
        ensure_connected!
        load_factories!

        business_type ||= EposNowSandboxSimulator.configuration.business_type
        Seeder.seed!(business_type: business_type)
      end

      def connected?
        ActiveRecord::Base.connection_pool.with_connection(&:active?)
      rescue StandardError
        false
      end

      def disconnect!
        ActiveRecord::Base.connection_pool.disconnect!
        EposNowSandboxSimulator.logger.info("Database disconnected")
      end

      def test_database_url(base_url: nil)
        url = base_url || Configuration.database_url_from_file
        return "postgres://localhost:5432/#{TEST_DATABASE}" if url.nil?

        uri = URI.parse(url)
        uri.path = "/#{TEST_DATABASE}"
        uri.to_s
      rescue URI::InvalidURIError
        "postgres://localhost:5432/#{TEST_DATABASE}"
      end

      private

      def ensure_connected!
        return if connected?

        raise EposNowSandboxSimulator::Error,
              "Database not connected. Call Database.connect!(url) first."
      end

      def load_factories!
        return if @factories_loaded

        require "factory_bot"

        factories_path = File.expand_path("db/factories", __dir__)
        FactoryBot.definition_file_paths = [factories_path] if Dir.exist?(factories_path)
        FactoryBot.find_definitions
        @factories_loaded = true
      rescue StandardError => e
        EposNowSandboxSimulator.logger.warn("Could not load factories: #{e.message}")
      end

      def sanitize_url(url)
        uri = URI.parse(url)
        has_password = !uri.password.nil?
        uri.user = "***" if uri.user
        uri.password = "***" if has_password
        uri.to_s
      rescue URI::InvalidURIError
        url.gsub(%r{://[^@]+@}, "://***:***@")
      end
    end
  end
end
