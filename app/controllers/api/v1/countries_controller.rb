# frozen_string_literal: true

class Api::V1::CountriesController < Api::V1::BaseController
  skip_before_action :authenticate_request!
  skip_before_action :check_api_key_rate_limit
  skip_before_action :log_api_access
  # The country picker runs before sign-up (issue #106, Story 1.1).
  skip_before_action :ensure_verified_for_financial_data

  def index
    render json: { countries: ChancenCountry.live.map(&:as_json) }
  end
end
