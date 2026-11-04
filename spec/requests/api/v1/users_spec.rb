# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Users', type: :request do
  let(:family) do
    Family.create!(
      name: 'API Family',
      currency: 'USD',
      locale: 'en',
      date_format: '%m-%d-%Y'
    )
  end

  let(:role) { :admin }

  let(:user) do
    family.users.create!(
      email: 'api-user@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      role: role
    )
  end

  let(:api_key) do
    key = ApiKey.generate_secure_key
    ApiKey.create!(
      user: user,
      name: 'API Docs Key',
      key: key,
      scopes: %w[read_write],
      source: 'web'
    )
  end

  let(:'X-Api-Key') { api_key.plain_key }

  path '/api/v1/users/reset' do
    delete 'Reset account' do
      tags 'Users'
      description 'Resets all financial data (accounts, categories, merchants, tags, etc.) ' \
                  'for the current user\'s family while keeping the user account intact. ' \
                  'The reset runs asynchronously in the background. ' \
                  'The returned job_id is informational only; reset status is family-scoped, not job-scoped. ' \
                  'Requires admin role.'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'

      response '200', 'account reset initiated' do
        schema '$ref' => '#/components/schemas/ResetInitiatedResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { 'invalid-key' }

        run_test!
      end

      response '403', 'forbidden - requires read_write scope and admin role' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:api_key) do
          key = ApiKey.generate_secure_key
          ApiKey.create!(
            user: user,
            name: 'Read Only Key',
            key: key,
            scopes: %w[read],
            source: 'web'
          )
        end

        run_test!
      end

      response '500', 'reset enqueue failed' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        before do
          allow(FamilyResetJob).to receive(:perform_later).and_raise(StandardError, 'queue down')
        end

        run_test!
      end
    end
  end

  path '/api/v1/users/reset/status' do
    get 'Retrieve reset status' do
      tags 'Users'
      description 'Returns counts of family-owned data targeted by account reset. ' \
                  'Use this after DELETE /api/v1/users/reset to decide whether reset materialization has completed. ' \
                  'Completion is a counts-based family snapshot and may change if new data is created after reset.'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'

      response '200', 'reset status returned' do
        schema '$ref' => '#/components/schemas/ResetStatusResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { 'invalid-key' }

        run_test!
      end

      response '403', 'forbidden - requires admin role' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:role) { :member }

        run_test!
      end
    end
  end

  path '/api/v1/users/me' do
    get 'Get current user' do
      tags 'Users'
      description 'Returns the current user profile used by the mobile app ' \
                  '(verification state, country, consent, and whether a password is set). ' \
                  'Available before email verification.'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'

      response '200', 'user returned' do
        run_test!
      end

      response '401', 'unauthorized' do
        let(:'X-Api-Key') { 'invalid-key' }

        run_test!
      end
    end

    delete 'Delete account' do
      tags 'Users'
      description 'Permanently deactivates the current user account and all associated data. ' \
                  'This action cannot be undone.'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'

      response '200', 'account deleted' do
        schema '$ref' => '#/components/schemas/SuccessMessage'

        run_test!
      end

      response '401', 'unauthorized' do
        let(:'X-Api-Key') { 'invalid-key' }

        run_test!
      end

      response '403', 'insufficient scope' do
        let(:api_key) do
          key = ApiKey.generate_secure_key
          ApiKey.create!(
            user: user,
            name: 'Read Only Key',
            key: key,
            scopes: %w[read],
            source: 'web'
          )
        end

        run_test!
      end

      response '422', 'deactivation failed' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        before do
          api_key
          allow_any_instance_of(User).to receive(:deactivate).and_return(false)
          allow_any_instance_of(User).to receive(:errors).and_return(
            double(full_messages: [ 'Cannot deactivate admin with other users' ])
          )
        end

        run_test!
      end
    end
  end

  path '/api/v1/users/me/country' do
    patch 'Update country and consent' do
      tags 'Users'
      description 'Records the member\'s country and the privacy/terms version they accepted. ' \
                  'The country is locked once set — only a matching code is accepted afterwards. ' \
                  'Available before email verification.'
      security [ { apiKeyAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              country_code: { type: :string, example: 'KE' },
              consent_version: { type: :string, example: '1.0' }
            }
          }
        }
      }

      let(:payload) { { user: { country_code: 'KE', consent_version: '1.0' } } }

      response '200', 'country and consent saved' do
        run_test!
      end

      response '401', 'unauthorized' do
        let(:'X-Api-Key') { 'invalid-key' }

        run_test!
      end

      response '403', 'insufficient scope' do
        let(:api_key) do
          key = ApiKey.generate_secure_key
          ApiKey.create!(
            user: user,
            name: 'Read Only Key',
            key: key,
            scopes: %w[read],
            source: 'web'
          )
        end

        run_test!
      end
    end
  end

  path '/api/v1/users/me/password' do
    patch 'Update password' do
      tags 'Users'
      description 'Sets or changes the current user\'s password. SSO-only accounts (no password yet) ' \
                  'may set one without providing a current password. Available before email verification.'
      security [ { apiKeyAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              current_password: { type: :string },
              password: { type: :string }
            }
          }
        }
      }

      let(:payload) { { user: { current_password: 'password123', password: 'NewPassword123' } } }

      response '200', 'password updated' do
        run_test!
      end

      response '401', 'unauthorized' do
        let(:'X-Api-Key') { 'invalid-key' }

        run_test!
      end

      response '422', 'current password incorrect' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:payload) { { user: { current_password: 'wrong-password', password: 'NewPassword123' } } }

        run_test!
      end
    end
  end
end
