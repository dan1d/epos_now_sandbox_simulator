# frozen_string_literal: true

module EposNowSandboxSimulator
  module Models
    class ApiRequest < ActiveRecord::Base
      self.table_name = "api_requests"

      validates :http_method, presence: true
      validates :url, presence: true

      scope :errors, -> { where.not(error_message: nil) }
      scope :by_resource, ->(type) { where(resource_type: type) }
      scope :recent, -> { order(created_at: :desc) }
    end
  end
end
