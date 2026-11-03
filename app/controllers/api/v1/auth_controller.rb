module Api
  module V1
    class AuthController < BaseController
      include Invitable

      skip_before_action :authenticate_request!
      skip_before_action :check_api_key_rate_limit
      skip_before_action :log_api_access
      skip_before_action :ensure_verified_for_financial_data
      before_action :authenticate_request!, only: %i[enable_ai resend_email_verification]
      before_action :ensure_write_scope, only: %i[enable_ai resend_email_verification]
      before_action :check_api_key_rate_limit, only: %i[enable_ai resend_email_verification]
      before_action :log_api_access, only: %i[enable_ai resend_email_verification]
      rescue_from SsoIdentityBlock::BlockedIdentity, with: :render_removed_identity

      EMAIL_VERIFICATION_RESENDS_PER_HOUR = 3

      def signup
        # invite_code_required? consults @invitation, so resolve it before checking invite-code requirements.
        @invitation = pending_invitation_from_params
        return render_signup_not_permitted_json unless signup_permitted?(invitation: @invitation)

        # RegistrationsController refuses to register a user while the instance
        # is closed. That gate is declared `if: :self_hosted?`, but
        # onboarding_state only ever reaches "closed" on a self-hosted
        # instance, so checking the state alone matches its effect.
        if Setting.onboarding_state == "closed"
          render json: { error: "Registration is currently closed" }, status: :forbidden
          return
        end

        # Check if invite code is required
        if invite_code_required? && params[:invite_code].blank?
          render json: { error: "Invite code is required" }, status: :forbidden
          return
        end

        # Validate invite code if provided
        if params[:invite_code].present? && !InviteCode.exists?(token: params[:invite_code]&.downcase)
          render json: { error: "Invalid invite code" }, status: :forbidden
          return
        end

        # Validate password
        password_errors = validate_password(params[:user][:password])
        if password_errors.any?
          render json: { errors: password_errors }, status: :unprocessable_entity
          return
        end

        # Validate device info
        unless valid_device_info?
          render json: { error: "Device information is required" }, status: :bad_request
          return
        end

        user = User.new(user_signup_params)

        # Assigns the invitation's family/role, the invite-only default family,
        # or a brand-new family whose first instance user becomes super_admin.
        assign_signup_family_and_role(user, invitation: @invitation)

        # Atomic: user creation, invite-code claim, and device/token issuance
        # either all commit or none do. Without this, a post-commit device
        # failure (e.g., racing uniqueness) would leave the user/invite/family
        # committed while the client got a 422 "Failed to register device".
        token_response = nil
        begin
          ActiveRecord::Base.transaction do
            # New-family creators: lock first so the first-user super_admin
            # decision is race-safe. Invitation/default-family roles are already
            # set by assign_signup_family_and_role and must not be overwritten.
            unless @invitation.present?
              User.lock_first_user_role!
              user.role = User.role_for_new_family_creator
            end

            unless user.save
              render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
              raise ActiveRecord::Rollback
            end
            InviteCode.claim!(params[:invite_code]) if params[:invite_code].present?
            @invitation&.accept_signup!(user)
            device = MobileDevice.upsert_device!(user, device_params)
            token_response = device.issue_token!
          end
        rescue ActiveRecord::RecordInvalid, User::InactiveError => e
          Rails.logger.error("[Auth] Device registration failed: #{e.class} - #{e.message}")
          render json: { error: "Failed to register device" }, status: :unprocessable_entity
          return
        end

        return unless token_response

        if invitation_token_proves_email?(@invitation, invitation_token_param)
          user.mark_email_verified!
        else
          user.send_email_verification
        end

        render json: token_response.merge(user: user.mobile_payload), status: :created
      end

      def login
        user = User.find_by(email: params[:email])

        unless local_login_permitted_for?(user)
          render json: { error: "Local login is disabled. Please use SSO." }, status: :forbidden
          return
        end

        if user&.authenticate(params[:password])
          unless user.active?
            render json: { error: "This account has been deactivated. Please contact an administrator." }, status: :unauthorized
            return
          end

          # Check MFA if enabled
          if user.otp_required?
            unless params[:otp_code].present? && user.verify_otp?(params[:otp_code])
              render json: {
                error: "Two-factor authentication required",
                mfa_required: true
              }, status: :unauthorized
              return
            end
          end

          # Validate device info
          unless valid_device_info?
            render json: { error: "Device information is required" }, status: :bad_request
            return
          end

          # Fast-path re-check to skip a pointless device upsert for a user
          # already known to be inactive — issue_token! re-checks active? under
          # lock immediately before minting (see its comment) and is the actual
          # authorization boundary, not this check. Treats a concurrently
          # purged user (reload raises RecordNotFound) the same as inactive.
          unless user_reloadable_and_active?(user)
            render json: { error: "This account has been deactivated. Please contact an administrator." }, status: :unauthorized
            return
          end

          begin
            device = MobileDevice.upsert_device!(user, device_params)
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error("[Auth] Device registration failed: #{e.message}")
            render json: { error: "Failed to register device" }, status: :unprocessable_entity
            return
          end

          begin
            token_response = device.issue_token!
          rescue User::InactiveError
            render json: { error: "This account has been deactivated. Please contact an administrator." }, status: :unauthorized
            return
          end

          render json: token_response.merge(user: user.mobile_payload)
        else
          if user&.sso_only?
            render json: { error: "sso_account", message: "This account uses social sign-in. Sign in with Google or Apple instead." }, status: :unprocessable_entity
          else
            render json: { error: "Invalid email or password" }, status: :unauthorized
          end
        end
      end

      # Lists the providers GET /auth/mobile/:provider accepts, so clients can
      # render one button per provider. Only display fields are exposed; the
      # provider config also carries client secrets. Labels fall back the same
      # way as the web sign-in page.
      def sso_providers
        providers = Rails.configuration.x.auth.sso_providers.map do |provider|
          name = provider[:name].to_s
          strategy = provider[:strategy].to_s
          id = provider[:id].to_s
          default_label = if id == "google" || strategy == "google_oauth2"
            I18n.t("sessions.new.google_auth_connect")
          elsif id.present?
            I18n.t("sessions.new.#{id}", default: name.titleize)
          else
            name.titleize
          end

          { name: name, strategy: strategy, label: provider[:label].presence || default_label }
        end

        render json: { providers: providers }
      end

      def sso_exchange
        code = sso_exchange_params

        if code.blank?
          render json: { error: "invalid_or_expired_code", message: "Authorization code is required" }, status: :unauthorized
          return
        end

        cache_key = "mobile_sso:#{code}"
        cached = Rails.cache.read(cache_key)

        unless cached.present?
          render json: { error: "invalid_or_expired_code", message: "Authorization code is invalid or expired" }, status: :unauthorized
          return
        end

        # Atomic delete — only the request that successfully deletes the key may proceed.
        # This prevents a race where two concurrent requests both read the same code.
        unless Rails.cache.delete(cache_key)
          render json: { error: "invalid_or_expired_code", message: "Authorization code is invalid or expired" }, status: :unauthorized
          return
        end

        render json: {
          access_token: cached[:access_token],
          refresh_token: cached[:refresh_token],
          token_type: cached[:token_type],
          expires_in: cached[:expires_in],
          created_at: cached[:created_at],
          user: {
            id: cached[:user_id],
            email: cached[:user_email],
            first_name: cached[:user_first_name],
            last_name: cached[:user_last_name],
            ui_layout: cached[:user_ui_layout],
            ai_enabled: cached[:user_ai_enabled],
            email_verified: cached[:user_email_verified],
            country_code: cached[:user_country_code],
            requires_country_confirmation: cached.fetch(:user_requires_country_confirmation, cached[:user_country_code].blank?)
          }
        }
      end

      def sso_link
        linking_code = params[:linking_code]
        cached = validate_linking_code(linking_code)
        return unless cached

        user = User.authenticate_by(email: params[:email], password: params[:password])

        unless user
          render json: { error: "Invalid email or password" }, status: :unauthorized
          return
        end

        unless user.active?
          render json: { error: "This account has been deactivated. Please contact an administrator." }, status: :unauthorized
          return
        end

        if user.otp_required?
          render json: { error: "MFA users should sign in with email and password", mfa_required: true }, status: :unauthorized
          return
        end

        # Atomically claim the code before creating the identity
        return render json: { error: "Linking code is invalid or expired" }, status: :unauthorized unless consume_linking_code!(linking_code)

        device_info = cached[:device_info]
        device_info = device_info.symbolize_keys if device_info.respond_to?(:symbolize_keys)

        # The password proves the account, the provider proves its own email.
        # Only when that is the account's email does this verify it.
        if OidcIdentity.email_trusted?(provider: cached[:provider], issuer: cached[:issuer]) &&
            cached[:email].to_s.casecmp?(user.email)
          user.mark_email_verified!
        end

        # Identity creation, the audit record, and the actual token mint all
        # run in one transaction so a rejected request can't leave a linked
        # identity or a successful-link audit record behind. issue_token!'s
        # locked active? recheck (the real authorization boundary) is what
        # decides whether this commits or rolls everything back together.
        token_response = nil
        begin
          ActiveRecord::Base.transaction do
            OidcIdentity.create_from_omniauth(build_omniauth_hash(cached), user)

            SsoAuditLog.log_link!(
              user: user,
              provider: cached[:provider],
              request: request
            )

            device = MobileDevice.upsert_device!(user, device_info)
            token_response = device.issue_token!
          end
        rescue User::InactiveError
          restore_linking_code!(linking_code, cached)
          render json: { error: "This account has been deactivated. Please contact an administrator." }, status: :unauthorized
          return
        rescue ActiveRecord::RecordInvalid => e
          restore_linking_code!(linking_code, cached)
          Rails.logger.error("[Auth] Device registration failed: #{e.message}")
          render json: { error: "Failed to register device" }, status: :unprocessable_entity
          return
        end

        render json: token_response.merge(user: user.mobile_payload)
      end

      def sso_create_account
        linking_code = params[:linking_code]
        cached = validate_linking_code(linking_code)
        return unless cached

        email = cached[:email]

        # Check for a pending invitation for this email
        invitation = Invitation.pending.find_by(email: email)
        return render_signup_not_permitted_json unless signup_permitted?(invitation: invitation)

        unless invitation.present? || cached[:allow_account_creation]
          render json: { error: "SSO account creation is disabled. Please contact an administrator." }, status: :forbidden
          return
        end

        if invitation.blank? && invite_only_default_family_missing?
          render json: { error: "Invite-only default family is unavailable. Please contact an administrator." }, status: :forbidden
          return
        end

        # Atomically claim the code before creating the user
        return render json: { error: "Linking code is invalid or expired" }, status: :unauthorized unless consume_linking_code!(linking_code)

        user = jit_create_sso_user(
          email:                    email,
          first_name:               params[:first_name].presence || cached[:first_name],
          last_name:                params[:last_name].presence  || cached[:last_name],
          provider:                 cached[:provider],
          uid:                      cached[:uid],
          issuer:                   cached[:issuer],
          new_family_fallback_role: sso_provider_default_role(cached[:provider]) || :admin,
          invitation:               invitation,
          password:                 params[:password].presence
        )
        return unless user

        issue_mobile_tokens(user, cached[:device_info])
      end

      def apple_sign_in
        unless valid_device_info?
          render json: { error: "Device information is required" }, status: :bad_request
          return
        end

        identity_token = params[:identity_token]
        if identity_token.blank?
          render json: { error: "identity_token is required" }, status: :bad_request
          return
        end

        claims = AppleSignIn.verify!(identity_token)
        apple_uid = claims["sub"]
        # Only the email inside Apple's signed token proves anything. A client-
        # supplied email must never link to, verify or create an account.
        email     = claims["email"].presence

        identity = OidcIdentity.find_by(provider: "apple", uid: apple_uid)

        user = if identity
          identity.user.tap { |identity_user| identity_user.claim_by_trusted_provider!(email: email) }
        elsif email.present? && (existing_user = User.find_by(email: email))
          OidcIdentity.create!(
            user: existing_user,
            provider: "apple",
            uid: apple_uid,
            issuer: AppleSignIn::ISSUER,
            info: {
              email: email,
              first_name: params[:first_name].presence || existing_user.first_name,
              last_name: params[:last_name].presence || existing_user.last_name
            },
            last_authenticated_at: Time.current
          )
          # Apple has proven control of this email; end any login held by
          # whoever registered it first (and, if unverified, their password
          # and MFA). issue_mobile_tokens below then issues the only valid token.
          existing_user.claim_by_trusted_provider!(email: email)
          existing_user.revoke_all_access!
          existing_user
        else
          unless email.present?
            render json: { error: "Please share your email address with Companion to continue." }, status: :unprocessable_entity
            return
          end

          new_user = jit_create_sso_user(
            email:      email,
            first_name: params[:first_name].presence || email.split("@").first,
            last_name:  params[:last_name].presence  || "",
            provider:   "apple",
            uid:        apple_uid,
            issuer:     AppleSignIn::ISSUER
          )
          return unless new_user
          new_user
        end

        issue_mobile_tokens(user, device_params)
      rescue AppleSignIn::Error => e
        Rails.logger.warn("[Auth] Apple Sign-In verification failed: #{e.message}")
        render json: { error: "Invalid Apple identity token" }, status: :unauthorized
      end

      def request_password_reset
        email = params[:email].to_s.strip.downcase
        user = User.find_by(email: email)

        if user && !user.sso_only? && AuthConfig.password_features_enabled?
          token = user.generate_token_for(:password_reset)
          PasswordMailer.with(user: user, token: token).mobile_password_reset.deliver_later
        end

        render json: { message: "If an account exists, you'll receive a reset link shortly." }
      end

      def reset_password
        unless AuthConfig.password_features_enabled?
          render json: { error: "Password reset is not available." }, status: :forbidden
          return
        end

        user = User.find_by_token_for(:password_reset, params[:token].to_s)

        unless user
          render json: { error: "Reset link is invalid or has expired." }, status: :unprocessable_entity
          return
        end

        if user.sso_only?
          render json: { error: "This account uses social sign-in. Password reset is not available." }, status: :unprocessable_entity
          return
        end

        unless user.update(password: params[:password], password_confirmation: params[:password_confirmation])
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          return
        end

        user.revoke_all_access!
        user.verify_after_password_reset!

        render json: { message: "Password updated. You've been signed out on all devices." }
      end

      def enable_ai
        user = current_resource_owner

        unless user.ai_available?
          render json: { error: "AI is not available for your account" }, status: :forbidden
          return
        end

        if user.update(ai_enabled: true)
          render json: { user: user.mobile_payload }
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def resend_email_verification
        user = current_resource_owner

        if user.email_verified?
          return render json: { message: "Your email is already verified.", user: user.mobile_payload }
        end

        sent = Rails.cache.increment("email_verification_resend:#{user.id}", 1, expires_in: 1.hour).to_i
        if sent > EMAIL_VERIFICATION_RESENDS_PER_HOUR
          return render json: { error: "Too many verification emails. Please try again in an hour." }, status: :too_many_requests
        end

        user.send_email_verification
        render json: { message: "Verification email sent.", user: user.mobile_payload }
      end

      def refresh
        # Find the refresh token
        refresh_token = params[:refresh_token]

        unless refresh_token.present?
          render json: { error: "Refresh token is required" }, status: :bad_request
          return
        end

        # Find the access token associated with this refresh token
        access_token = Doorkeeper::AccessToken.by_refresh_token(refresh_token)

        if access_token.nil? || access_token.revoked?
          render json: { error: "Invalid refresh token" }, status: :unauthorized
          return
        end

        user = User.find_by(id: access_token.resource_owner_id)
        new_token = begin
          user&.with_active_lock! do
            access_token.with_lock do
              next false if access_token.revoked?

              token = Doorkeeper::AccessToken.create!( # pipelock:ignore Credential in URL
                application: access_token.application,
                resource_owner_id: access_token.resource_owner_id,
                mobile_device_id: access_token.mobile_device_id,
                expires_in: 30.days.to_i,
                scopes: access_token.scopes,
                use_refresh_token: true
              )

              access_token.revoke
              device = user.mobile_devices.find_by(device_id: params.dig(:device, :device_id))
              device&.update_last_seen!
              token
            end
          end
        rescue ActiveRecord::RecordNotFound, User::InactiveError
          false
        end

        unless new_token
          render json: { error: "Invalid refresh token" }, status: :unauthorized
          return
        end

        render json: {
          access_token: new_token.plaintext_token,
          refresh_token: new_token.plaintext_refresh_token,
          token_type: "Bearer",
          expires_in: new_token.expires_in,
          created_at: new_token.created_at.to_i
        }
      end

      private

        # Mirrors SessionsController#create: with SSO-only mode on, the only
        # local sign-in allowed is a super admin using the emergency override.
        def local_login_permitted_for?(user)
          return true if AuthConfig.local_login_enabled?

          AuthConfig.local_admin_override_enabled? && user&.super_admin?
        end

        def user_signup_params
          params.require(:user).permit(:email, :password, :first_name, :last_name, :country_code)
        end

        def invitation_token_param
          params[:invitation].presence || params.dig(:user, :invitation).presence
        end

        # The invitation for the token sent with the sign-up, otherwise the seat
        # reserved for this email (only invitations never emailed, such as bulk
        # invites; an emailed invitation needs its token). An email match
        # proves nothing about ownership: that account starts unverified, and
        # the real owner can reclaim it by password reset or Google/Apple.
        def pending_invitation_from_params
          token = invitation_token_param
          return Invitation.pending.find_by(token: token) if token.present?

          Invitation.seat_for(params.dig(:user, :email))
        end

        def validate_password(password)
          errors = []

          if password.blank?
            errors << "Password can't be blank"
            return errors
          end

          errors << "Password must be at least 8 characters" if password.length < 8
          errors << "Password must include both uppercase and lowercase letters" unless password.match?(/[A-Z]/) && password.match?(/[a-z]/)
          errors << "Password must include at least one number" unless password.match?(/\d/)
          errors << "Password must include at least one special character" unless password.match?(/[!@#$%^&*(),.?":{}|<>]/)

          errors
        end

        def valid_device_info?
          device = params[:device]
          return false if device.nil?

          required_fields = %w[device_id device_name device_type os_version app_version]
          return false unless required_fields.all? { |field| device[field].present? }

          # Run MobileDevice's attribute-level validations up front (e.g.,
          # device_type must be ios/android/web) so a misconfigured client
          # is rejected BEFORE signup commits user/family/invite. Skip
          # errors we can't evaluate without a user: the :user belongs_to
          # presence check, and device_id uniqueness scoped to user_id
          # (upsert_device! treats collisions as updates anyway).
          preview = MobileDevice.new(device_params)
          preview.valid?
          relevant_errors = preview.errors.errors.reject do |err|
            err.type == :taken || err.attribute == :user
          end
          relevant_errors.empty?
        end

        def device_params
          params.require(:device).permit(:device_id, :device_name, :device_type, :os_version, :app_version)
        end

        def sso_exchange_params
          params.require(:code)
        end

        def jit_create_sso_user(email:, first_name:, last_name:, provider:, uid:, issuer:, new_family_fallback_role: :admin, invitation: nil, password: nil)
          invitation ||= Invitation.pending.find_by(email: email)

          unless signup_permitted?(invitation: invitation)
            render_signup_not_permitted_json
            return nil
          end

          if invitation.blank? && invite_only_default_family_missing?
            render json: { error: "Invite-only default family is unavailable. Please contact an administrator." }, status: :forbidden
            return nil
          end

          user = User.new(
            email:      email,
            first_name: first_name,
            last_name:  last_name,
            skip_password_validation: password.blank?
          )
          user.password = password if password.present?
          assign_signup_family_and_role(user, invitation: invitation, new_family_fallback_role: new_family_fallback_role)

          ActiveRecord::Base.transaction do
            unless user.save
              render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
              raise ActiveRecord::Rollback
            end
            OidcIdentity.create!(
              user:                  user,
              provider:              provider,
              uid:                   uid,
              issuer:                issuer,
              info:                  { email: email, first_name: user.first_name, last_name: user.last_name },
              last_authenticated_at: Time.current
            )
            invitation&.accept_signup!(user)
            user.mark_email_verified! if OidcIdentity.email_trusted?(provider: provider, issuer: issuer)
            SsoAuditLog.log_jit_account_created!(user: user, provider: provider, request: request)
          end

          return nil if performed?
          user.send_email_verification unless user.email_verified?
          user
        end

        # A concurrent purge between the initial check and this fast-path
        # re-check raises RecordNotFound on reload; treat it the same as
        # inactive instead of letting it fall through to BaseController's
        # generic record_not_found handler.
        def user_reloadable_and_active?(user)
          user.reload.active?
        rescue ActiveRecord::RecordNotFound
          false
        end

        def build_omniauth_hash(cached)
          OpenStruct.new(
            provider: cached[:provider],
            uid: cached[:uid],
            info: OpenStruct.new(cached.slice(:email, :name, :first_name, :last_name)),
            extra: OpenStruct.new(raw_info: OpenStruct.new(iss: cached[:issuer]))
          )
        end

        def validate_linking_code(linking_code)
          if linking_code.blank?
            render json: { error: "Linking code is required" }, status: :bad_request
            return nil
          end

          cache_key = "mobile_sso_link:#{linking_code}"
          cached = Rails.cache.read(cache_key)

          unless cached.present?
            render json: { error: "Linking code is invalid or expired" }, status: :unauthorized
            return nil
          end

          if SsoIdentityBlock.blocked?(provider: cached[:provider], uid: cached[:uid])
            Rails.cache.delete(cache_key)
            render json: { error: "SSO identity was removed by an administrator" }, status: :forbidden
            return nil
          end

          cached
        end

        def render_removed_identity
          render json: { error: "SSO identity was removed by an administrator" }, status: :forbidden
        end

        # Atomically deletes the linking code from cache.
        # Returns true only for the first caller; subsequent callers get false.
        def consume_linking_code!(linking_code)
          Rails.cache.delete("mobile_sso_link:#{linking_code}")
        end

        # Best-effort restore so a request rejected *after* consuming the
        # code (deactivation race or a device-registration failure inside
        # the transaction) can retry with the same code instead of
        # restarting the SSO flow from the IdP. Safe to write back verbatim:
        # a legitimate retry re-authenticates with email/password from
        # scratch, and OidcIdentity's unique (provider, uid) index is the
        # backstop if a second request somehow raced onto the restored code.
        def restore_linking_code!(linking_code, cached)
          Rails.cache.write("mobile_sso_link:#{linking_code}", cached, expires_in: 10.minutes)
        end

        # Used by sso_create_account for its brand-new user (always active —
        # the reload is a harmless no-op there, but still races a concurrent
        # purge the same way login's fast path does). Reload right before
        # minting, same reasoning as Authentication#create_session_for.
        def issue_mobile_tokens(user, device_info)
          unless user_reloadable_and_active?(user)
            render json: { error: "This account has been deactivated. Please contact an administrator." }, status: :unauthorized
            return
          end

          device_info = device_info.symbolize_keys if device_info.respond_to?(:symbolize_keys)

          begin
            device = MobileDevice.upsert_device!(user, device_info)
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error("[Auth] Device registration failed: #{e.message}")
            render json: { error: "Failed to register device" }, status: :unprocessable_entity
            return
          end

          begin
            token_response = device.issue_token!
          rescue User::InactiveError
            render json: { error: "This account has been deactivated. Please contact an administrator." }, status: :unauthorized
            return
          end

          render json: token_response.merge(user: user.mobile_payload)
        end

        def ensure_write_scope
          authorize_scope!(:write)
        end
    end
  end
end
