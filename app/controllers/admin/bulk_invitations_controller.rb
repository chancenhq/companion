# frozen_string_literal: true

module Admin
  class BulkInvitationsController < Admin::BaseController
    def new
      @families = Family.order(:name)
    end

    def preview
      @family = Family.find(params[:family_id])
      @emails = parse_emails(params[:emails])
      @move_existing = params[:move_existing] == "1"
      @role = permitted_role(params[:role])
      @raw_emails = params[:emails]

      if @emails.empty?
        @families = Family.order(:name)
        flash.now[:alert] = t("admin.bulk_invitations.new.no_emails")
        render :new, status: :unprocessable_entity
      end
    end

    def create
      family = Family.find(params[:family_id])
      emails = parse_emails(params[:emails])

      if emails.empty?
        @families = Family.order(:name)
        @role = permitted_role(params[:role])
        flash.now[:alert] = t("admin.bulk_invitations.new.no_emails")
        return render :new, status: :unprocessable_entity
      end

      # Ensure the country family is private so students never see each other's data
      family.update!(default_account_sharing: "private") unless family.default_account_sharing == "private"

      move_existing = params[:move_existing] == "1"
      role = permitted_role(params[:role])
      @results = emails.map { |email| invite(email, family, role: role, move_existing: move_existing) }
      @family = family
    end

    private

      def parse_emails(raw)
        raw.to_s.split(/[\s,;]+/).map(&:strip).map(&:downcase).uniq.reject(&:blank?)
      end

      # Only member/guest can be assigned via bulk invite (never admin).
      # Defaults to guest — the Companion student experience (intro layout + AI).
      def permitted_role(raw)
        %w[member guest].include?(raw) ? raw : "guest"
      end

      # Reserves a seat for the email (issue #106): nothing is emailed. The
      # student installs the app and signs up with this email, or with
      # Google/Apple on it, and lands in this family. Existing accounts are
      # only moved when the admin explicitly asks for it.
      def invite(email, family, role:, move_existing:)
        existing_user = User.find_by(email: email)
        return { email: email, status: :existing } if existing_user && !move_existing

        invitation = Invitation.new(
          email:        email,
          role:         role,
          family:       family,
          inviter:      Current.user,
          country_code: family.chancen_country_code
        )

        if invitation.save
          if existing_user
            invitation.accept_for(existing_user)
            { email: email, status: :moved }
          else
            { email: email, status: :reserved, invitation_id: invitation.id }
          end
        else
          { email: email, status: :error, errors: invitation.errors.full_messages }
        end
      rescue => e
        { email: email, status: :error, errors: [ e.message ] }
      end
  end
end
