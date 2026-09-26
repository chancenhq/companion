# frozen_string_literal: true

module Admin
  class BulkInvitationsController < Admin::BaseController
    def new
      @families = Family.order(:name)
    end

    def create
      family = Family.find(params[:family_id])
      emails = parse_emails(params[:emails])

      if emails.empty?
        @families = Family.order(:name)
        flash.now[:alert] = t(".no_emails")
        return render :new, status: :unprocessable_entity
      end

      # Ensure the country family is private so students never see each other's data
      family.update!(default_account_sharing: "private") unless family.default_account_sharing == "private"

      @results = emails.map { |email| invite(email, family) }
      @family = family
      @families = Family.order(:name)
    end

    private

      def parse_emails(raw)
        raw.to_s.split(/[\s,;]+/).map(&:strip).map(&:downcase).uniq.reject(&:blank?)
      end

      def invite(email, family)
        invitation = Invitation.new(
          email:   email,
          role:    "member",
          family:  family,
          inviter: Current.user
        )

        if invitation.save
          existing_user = User.find_by(email: email)

          if existing_user
            invitation.accept_for(existing_user)
            { email: email, status: :accepted }
          else
            InvitationMailer.invite_email(invitation).deliver_later
            { email: email, status: :invited }
          end
        else
          { email: email, status: :error, errors: invitation.errors.full_messages }
        end
      rescue => e
        { email: email, status: :error, errors: [ e.message ] }
      end
  end
end
