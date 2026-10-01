# frozen_string_literal: true

class Api::V1::CountriesController < Api::V1::BaseController
  skip_before_action :authenticate_request!
  skip_before_action :check_api_key_rate_limit
  skip_before_action :log_api_access

  def index
    render json: { countries: ChancenCountry.live.map(&:as_json) }
  end
end
