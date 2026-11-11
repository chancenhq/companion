# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 App Config", type: :request do
  path "/api/v1/app_config" do
    get "Retrieve public mobile app configuration" do
      tags "App Config"
      description "Returns public, country-specific Contact Us links used by the mobile app."
      produces "application/json"

      response "200", "app configuration returned" do
        schema type: :object,
          required: [ "whatsapp_group_urls" ],
          properties: {
            whatsapp_group_urls: {
              type: :object,
              additionalProperties: { type: :string, format: :uri }
            }
          }

        run_test!
      end
    end
  end
end
