module Invitable
  extend ActiveSupport::Concern

  included do
    helper_method :invite_code_required?
  end

  private
    # One sign-up rule for every account-creation path (web, mobile email,
    # Apple, Google/OIDC). Only creation is gated; existing users sign in as usual.
    #   open        -> anyone
    #   invite_only -> only with a pending invitation: the emailed token for
    #                  email sign-up, a provider-verified email match for
    #                  Google/Apple. Invite codes and the default family don't count.
    #   closed      -> nobody, invitations included
    def signup_permitted?(invitation:)
      case Setting.onboarding_state
      when "closed" then false
      when "invite_only" then invitation.present?
      else true
      end
    end

    # Signing up with the token from an invitation that was emailed proves the
    # address. A seat matched by email alone (e.g. bulk invite, nothing sent)
    # proves nothing, so that account starts unverified.
    def invitation_token_proves_email?(invitation, token)
      invitation.present? && token.present? && invitation.emailed?
    end

    def signup_not_permitted_message
      Setting.onboarding_state == "closed" ? t("registrations.closed") : t("registrations.invite_only")
    end

    # The mobile app shows `error` verbatim, so it carries the readable message.
    def render_signup_not_permitted_json
      render json: { error: signup_not_permitted_message }, status: :forbidden
    end

    def invite_code_required?
      return false if @invitation.present?
      if self_hosted?
        Setting.onboarding_state == "invite_only" && invite_only_default_family.blank?
      else
        ENV["REQUIRE_INVITE_CODE"] == "true"
      end
    end

    def assign_signup_family_and_role(user, invitation: nil, new_family_fallback_role: :admin)
      if invitation.present?
        user.family = invitation.family
        user.role = invitation.role
        user.email = invitation.email if user.respond_to?(:email=)
      elsif (default_family = invite_only_default_family)
        user.family = default_family
        user.role = :member
      else
        user.family = Family.new
        user.role = User.role_for_new_family_creator(fallback_role: new_family_fallback_role)
      end
    end

    def sso_provider_default_role(provider_name)
      provider_config = Rails.configuration.x.auth.sso_providers&.find do |provider|
        provider[:name] == provider_name || provider[:id] == provider_name
      end
      settings = provider_config&.dig(:settings)

      settings&.dig(:default_role) || settings&.dig("default_role")
    end

    def invite_only_default_family
      default_family_id = Setting.invite_only_default_family_id
      return unless default_family_id.present? && Setting.onboarding_state == "invite_only"

      Family.find_by(id: default_family_id)
    end

    def invite_only_default_family_missing?
      Setting.onboarding_state == "invite_only" &&
        Setting.invite_only_default_family_id.present? &&
        invite_only_default_family.blank?
    end

    def self_hosted?
      Rails.application.config.app_mode.self_hosted?
    end
end
