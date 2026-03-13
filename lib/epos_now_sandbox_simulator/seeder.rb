# frozen_string_literal: true

module EposNowSandboxSimulator
  # Seeds the database with business types, categories, and items.
  # Idempotent — safe to call multiple times.
  module Seeder
    SEED_MAP = {
      restaurant: {
        industry: "Food",
        categories: {
          appetizers: %i[buffalo_wings mozzarella_sticks loaded_nachos bruschetta calamari],
          entrees: %i[grilled_salmon ny_strip_steak chicken_parmesan fish_and_chips pasta_alfredo bbq_ribs caesar_salad],
          sides: %i[french_fries coleslaw mac_and_cheese garden_salad onion_rings],
          drinks: %i[coca_cola iced_tea draft_beer house_wine lemonade],
          desserts: %i[chocolate_cake cheesecake ice_cream_sundae]
        }
      },
      cafe_bakery: {
        industry: "Food",
        categories: {
          hot_drinks: %i[espresso cappuccino latte hot_chocolate english_breakfast_tea],
          cold_drinks: %i[iced_latte iced_americano smoothie fresh_orange_juice],
          pastries: %i[croissant pain_au_chocolat blueberry_muffin cinnamon_roll scone],
          sandwiches: %i[club_sandwich blt avocado_toast panini chicken_wrap],
          cakes: %i[carrot_cake victoria_sponge brownie lemon_drizzle red_velvet_slice]
        }
      },
      bar_nightclub: {
        industry: "Food",
        categories: {
          draft_beer: %i[ipa_pint lager_pint stout_pint wheat_beer pale_ale],
          bottled_beer: %i[corona heineken budweiser seltzer],
          cocktails: %i[margarita old_fashioned mojito espresso_martini long_island],
          wine: %i[house_red_wine house_white_wine prosecco],
          bar_snacks: %i[chicken_wings loaded_fries nachos slider_trio mixed_nuts]
        }
      },
      retail_general: {
        industry: "Retail",
        categories: {
          electronics: %i[phone_charger bluetooth_speaker usb_cable],
          clothing: %i[t_shirt baseball_cap socks_pack],
          home_and_garden: %i[candle plant_pot picture_frame],
          health_beauty: %i[hand_cream lip_balm],
          groceries: %i[snack_bar water_bottle]
        }
      }
    }.freeze

    class << self
      # Seed database with business type data
      #
      # @param business_type [Symbol, String, nil] Specific type or nil for all
      # @return [Hash] Summary counts
      def seed!(business_type: nil)
        types = business_type ? [business_type.to_sym] : SEED_MAP.keys

        counts = { business_types: 0, categories: 0, items: 0 }

        types.each do |bt_key|
          bt_config = SEED_MAP[bt_key]
          next unless bt_config

          bt = find_or_create_business_type(bt_key, bt_config)
          counts[:business_types] += 1

          seed_categories(bt, bt_key, bt_config, counts)
        end

        EposNowSandboxSimulator.logger.info "Seeded: #{counts}"
        counts
      end

      private

      def find_or_create_business_type(bt_key, bt_config)
        Models::BusinessType.find_or_create_by!(key: bt_key.to_s) do |b|
          b.name = humanize_key(bt_key)
          b.industry = bt_config[:industry]
        end
      end

      def seed_categories(bt, bt_key, bt_config, counts)
        loader = Generators::DataLoader.new(business_type: bt_key)
        items_data = loader.load_items

        bt_config[:categories].each_with_index do |(cat_key, item_keys), idx|
          cat = Models::Category.find_or_create_by!(
            business_type: bt,
            name: humanize_key(cat_key)
          ) do |c|
            c.sort_order = idx + 1
          end
          counts[:categories] += 1

          seed_items(bt, cat, item_keys, items_data, counts)
        end
      end

      def seed_items(bt, cat, item_keys, items_data, counts)
        item_keys.each do |item_key|
          item_name = humanize_key(item_key)
          json_item = items_data.find { |i| i["name"] == item_name }

          Models::Item.find_or_create_by!(business_type: bt, name: item_name) do |i|
            i.category = cat
            i.price = json_item ? (json_item["price"] * 100).round : 999
            i.sku = json_item&.dig("sku")
          end
          counts[:items] += 1
        end
      end

      def humanize_key(key)
        key.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
      end
    end
  end
end
