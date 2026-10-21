# Chancen students (User#companion?) get the web equivalent of the mobile app:
# the assistant, their Chancen Account and a small settings area. Everything
# else in the app is closed to them. A controller or action missing from
# ALLOWLIST is blocked by default; test/controllers/companion_access_test.rb
# fails if a new page is reachable without a decision here.
module CompanionRestrictable
  extend ActiveSupport::Concern

  ALLOWLIST = {
    # Signing in and out, password and email flows
    "sessions" => :all,
    "password_resets" => :all,
    "passwords" => :all,
    "email_confirmations" => :all,
    "oidc_accounts" => :all,
    "current_sessions" => :all,
    "mfa" => %w[verify verify_code webauthn_options verify_webauthn],
    # Lets a super admin leave an impersonation session
    "impersonation_sessions" => :all,
    # Assistant
    "chats" => :all,
    "messages" => :all,
    # Chancen Account (placeholder until the web pages exist)
    "my_accounts" => :all,
    # Own account and settings
    "users" => %w[update destroy resend_confirmation_email],
    "settings/profiles" => %w[show],
    "settings/appearances" => :all,
    # Home redirects to the assistant; legal pages
    "pages" => %w[dashboard privacy terms]
  }.freeze

  included do
    before_action :restrict_companion_access
  end

  class_methods do
    def companion_allowed?(controller_path, action_name)
      actions = ALLOWLIST[controller_path]
      actions == :all || Array(actions).include?(action_name.to_s)
    end
  end

  private
    def restrict_companion_access
      return unless Current.user&.companion?
      return if self.class.companion_allowed?(controller_path, action_name)

      respond_to do |format|
        format.html { redirect_to chats_path, alert: t("shared.companion_not_available") }
        format.any { head :forbidden }
      end
    end
end
