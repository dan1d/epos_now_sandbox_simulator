# frozen_string_literal: true

module EposNowSandboxSimulator
  module Models
    class Item < ActiveRecord::Base
      self.table_name = "items"

      belongs_to :business_type, class_name: "EposNowSandboxSimulator::Models::BusinessType"
      belongs_to :category, class_name: "EposNowSandboxSimulator::Models::Category", optional: true

      validates :name, presence: true
      validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
      validates :sku, uniqueness: { allow_nil: true }

      scope :for_business_type, ->(bt) { where(business_type: bt) }
      scope :for_category, ->(cat) { where(category: cat) }
      scope :by_price, -> { order(price: :asc) }
    end
  end
end
