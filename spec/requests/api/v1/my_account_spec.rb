# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 My Account', type: :request do
  let(:family) do
    Family.create!(name: 'API Family', currency: 'USD', locale: 'en', date_format: '%m-%d-%Y')
  end

  let(:user) do
    family.users.create!(email: 'api-user@example.com', password: 'password123', password_confirmation: 'password123')
  end

  let(:api_key) do
    key = ApiKey.generate_secure_key
    ApiKey.create!(user: user, name: 'API Docs Key', key: key, scopes: %w[read_write], source: 'web')
  end

  let(:'X-Api-Key') { api_key.plain_key }

  path '/api/v1/my_account' do
    get 'Get current student ISA account data' do
      tags 'My Account'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'
      description 'Returns the ISA financing and instalment data for the authenticated student, ' \
                  'sourced from a Chancen-managed Google Sheet. Returns 503 if the sheet is not ' \
                  'configured, 404 if the student email is not found in the sheet.'

      response '200', 'account data returned' do
        schema '$ref' => '#/components/schemas/StudentAccount'
        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end

      response '404', 'student not found in sheet' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end

      response '503', 'sheet not configured' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end
    end
  end
end
