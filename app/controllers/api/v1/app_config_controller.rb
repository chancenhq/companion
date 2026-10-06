class Api::V1::AppConfigController < Api::V1::BaseController
  skip_before_action :authenticate_request!
  # Public WhatsApp links: also outside the #106 email-verification lock
  # once it lands from merge-3 (raise: false keeps this a no-op until then).
  skip_before_action :ensure_verified_for_financial_data, raise: false

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
