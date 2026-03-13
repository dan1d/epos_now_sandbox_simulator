# frozen_string_literal: true

module EposNowSandboxSimulator
  module Models
    class Category < ActiveRecord::Base
      self.table_name = "categories"

      belongs_to :business_type, class_name: "EposNowSandboxSimulator::Models::BusinessType"
      has_many :items, class_name: "EposNowSandboxSimulator::Models::Item", dependent: :nullify

      validates :name, presence: true
      validates :sort_order, presence: true
      validates :name, uniqueness: { scope: :business_type_id }

      scope :for_business_type, ->(bt) { where(business_type: bt) }
    end
  end
end
