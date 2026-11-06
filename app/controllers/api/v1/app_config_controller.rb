# frozen_string_literal: true

class Api::V1::AppConfigController < Api::V1::BaseController
  skip_before_action :authenticate_request!
  skip_before_action :ensure_verified_for_financial_data

  def show
    render json: {
      posthog: {
        host: Setting.posthog_host.presence,
        api_key: Setting.posthog_public_key.presence
      }.compact
    }
  end
end
