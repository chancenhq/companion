# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 App Config", type: :request do
  path "/api/v1/app_config" do
    get "Retrieve public mobile app configuration" do
      tags "App Config"
      description "Returns public client configuration used to initialize mobile services."
      produces "application/json"

      response "200", "app configuration returned" do
        schema type: :object,
          required: [ "posthog" ],
          properties: {
            posthog: {
              type: :object,
              properties: {
                host: { type: :string, format: :uri, nullable: true },
                api_key: { type: :string, nullable: true }
              }
            }
          }

        run_test!
      end
    end
  end
end
