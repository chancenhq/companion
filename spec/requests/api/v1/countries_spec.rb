# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Countries', type: :request do
  path '/api/v1/countries' do
    get 'List Chancen countries' do
      tags 'Countries'
      description 'Countries a member can pick (issue #106, Story 1.1), from config/chancen_countries.yml. ' \
                  'Public: the picker runs before sign-up.'
      produces 'application/json'

      response '200', 'countries listed' do
        schema type: :object,
               properties: {
                 countries: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       code: { type: :string, example: 'KE' },
                       name: { type: :string },
                       live: { type: :boolean },
                       team_name: { type: :string },
                       escalation_contact: { type: :string },
                       privacy_url: { type: :string },
                       terms_url: { type: :string },
                       isa_content_source: { type: :string }
                     }
                   }
                 }
               }
        run_test!
      end
    end
  end
end
