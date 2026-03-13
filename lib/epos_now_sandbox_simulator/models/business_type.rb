# frozen_string_literal: true

module EposNowSandboxSimulator
  module Models
    class BusinessType < ActiveRecord::Base
      self.table_name = "business_types"

      has_many :categories, class_name: "EposNowSandboxSimulator::Models::Category", dependent: :destroy
      has_many :items, class_name: "EposNowSandboxSimulator::Models::Item", dependent: :destroy

      validates :key, presence: true, uniqueness: true
      validates :name, presence: true
      validates :industry, presence: true
    end
  end
end
