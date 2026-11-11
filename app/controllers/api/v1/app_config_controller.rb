# frozen_string_literal: true

class Api::V1::AppConfigController < Api::V1::BaseController
  skip_before_action :authenticate_request!
  skip_before_action :check_api_key_rate_limit
  skip_before_action :log_api_access
  skip_before_action :ensure_verified_for_financial_data

  def show
    render json: {
      whatsapp_group_urls: {
        ke: Setting.whatsapp_group_url_ke.presence,
        rw: Setting.whatsapp_group_url_rw.presence,
        za: Setting.whatsapp_group_url_za.presence,
        gh: Setting.whatsapp_group_url_gh.presence
      }.compact
    }
  end
end
