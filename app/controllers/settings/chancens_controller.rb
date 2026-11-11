class Settings::ChancensController < ApplicationController
  layout "settings"

  WHATSAPP_URL_FIELDS = {
    whatsapp_group_url_ke: "WHATSAPP_GROUP_URL_KE",
    whatsapp_group_url_rw: "WHATSAPP_GROUP_URL_RW",
    whatsapp_group_url_za: "WHATSAPP_GROUP_URL_ZA",
    whatsapp_group_url_gh: "WHATSAPP_GROUP_URL_GH"
  }.freeze

  before_action :ensure_super_admin
  before_action :set_breadcrumbs

  def show
  end

  def update
    if chancen_params.key?(:metabase_url)
      Setting.metabase_url = chancen_params[:metabase_url]
    end

    update_encrypted_setting(:metabase_api_key)

    if chancen_params.key?(:metabase_student_question_id)
      Setting.metabase_student_question_id = chancen_params[:metabase_student_question_id]
    end

    if chancen_params.key?(:metabase_transactions_question_id)
      Setting.metabase_transactions_question_id = chancen_params[:metabase_transactions_question_id]
    end

    if chancen_params.key?(:metabase_email_param)
      Setting.metabase_email_param = chancen_params[:metabase_email_param].presence || "email"
    end

    whatsapp_params = chancen_params.slice(*WHATSAPP_URL_FIELDS.keys).to_h.symbolize_keys
    invalid_field = whatsapp_params.find do |field, value|
      ENV[WHATSAPP_URL_FIELDS.fetch(field)].blank? && value.present? && !valid_whatsapp_url?(value)
    end

    if invalid_field
      flash.now[:alert] = t(".invalid_whatsapp_url")
      return render :show, status: :unprocessable_entity
    end

    whatsapp_params.each do |field, value|
      next if ENV[WHATSAPP_URL_FIELDS.fetch(field)].present?

      Setting.public_send(:"#{field}=", value.to_s.strip.presence)
    end

    redirect_to settings_chancen_path, notice: t(".success")
  end

  private
    def chancen_params
      return ActionController::Parameters.new unless params.key?(:setting)

      params.require(:setting).permit(
        :metabase_url, :metabase_api_key, :metabase_student_question_id,
        :metabase_transactions_question_id, :metabase_email_param,
        *WHATSAPP_URL_FIELDS.keys
      )
    end

    def set_breadcrumbs
      @breadcrumbs = [
        [ t("breadcrumbs.home"), root_path ],
        [ t("settings.chancens.show.title"), nil ]
      ]
    end

    # Chancen integration config is restricted to super admins (mirrors
    # companion's dedicated Chancen settings page).
    def ensure_super_admin
      return if Current.user&.super_admin?

      redirect_to root_path, alert: t("settings.chancens.not_authorized")
    end

    # Mirrors Settings::HostingsController: "********" is the masked placeholder
    # for an existing key and means "leave untouched"; a blank submission clears it.
    def update_encrypted_setting(param_key)
      return unless chancen_params.key?(param_key)

      value = chancen_params[param_key].to_s.strip
      return if value == "********"

      Setting.public_send(:"#{param_key}=", value.presence)
    end

    def valid_whatsapp_url?(value)
      uri = URI.parse(value.to_s.strip)
      uri.scheme == "https" && uri.host&.casecmp?("chat.whatsapp.com") && uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
    end
end
