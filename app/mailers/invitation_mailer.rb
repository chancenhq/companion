class InvitationMailer < ApplicationMailer
  # Only an invitation that reached the inbox makes its token proof of email
  # ownership at sign-up (Invitation#emailed?, issue #106).
  after_deliver :record_email_sent

  def invite_email(invitation)
    @invitation = invitation
    @accept_url = accept_invitation_url(@invitation.token)
    @mobile_accept_url = "sureapp://invite?token=#{@invitation.token}"

    mail(
      to: @invitation.email,
      subject: t(
        ".subject",
        inviter: @invitation.inviter.display_name,
        product_name: product_name
      )
    )
  end

  private

    def record_email_sent
      @invitation&.update_column(:email_sent_at, Time.current)
    end
end
