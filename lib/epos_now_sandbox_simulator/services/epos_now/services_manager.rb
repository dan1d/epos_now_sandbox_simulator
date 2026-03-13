# frozen_string_literal: true

require "concurrent"

module EposNowSandboxSimulator
  module Services
    module EposNow
      # Thread-safe, lazy-loaded service manager for all Epos Now services.
      #
      # @example
      #   services = ServicesManager.new
      #   services.inventory.create_category(name: "Drinks")
      #   services.transaction.create_transaction(eat_out: 0)
      class ServicesManager
        def initialize(config: nil)
          @config = config || EposNowSandboxSimulator.configuration
          @mutex = Mutex.new
        end

        def inventory
          thread_safe_memoize(:@inventory) { InventoryService.new(config: @config) }
        end

        def tender
          thread_safe_memoize(:@tender) { TenderService.new(config: @config) }
        end

        def transaction
          thread_safe_memoize(:@transaction) { TransactionService.new(config: @config) }
        end

        def tax
          thread_safe_memoize(:@tax) { TaxService.new(config: @config) }
        end

        private

        def thread_safe_memoize(ivar_name)
          value = instance_variable_get(ivar_name)
          return value if value

          @mutex.synchronize do
            # :nocov:
            value = instance_variable_get(ivar_name)
            return value if value
            # :nocov:

            value = yield
            instance_variable_set(ivar_name, value)
            value
          end
        end
      end
    end
  end
end
