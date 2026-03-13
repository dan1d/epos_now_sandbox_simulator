# frozen_string_literal: true

class CreateApiRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :api_requests, id: :uuid do |t|
      t.string :http_method, null: false
      t.string :url, null: false
      t.jsonb :request_payload, default: {}
      t.integer :response_status
      t.jsonb :response_payload, default: {}
      t.integer :duration_ms
      t.string :error_message
      t.string :resource_type
      t.string :resource_id

      t.timestamps

      t.index :resource_type
      t.index :created_at
    end
  end
end
