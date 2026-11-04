# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Countries', type: :request do
  path '/api/v1/countries' do
    get 'List countries' do
      tags 'Countries'
      description 'Lists the live Chancen countries with their Privacy Policy and Terms of Use links. ' \
                  'Public (no API key) because the picker and consent screen run before sign-up.'
      produces 'application/json'

      response '200', 'countries listed' do
        run_test!
      end
    end
  end
end
