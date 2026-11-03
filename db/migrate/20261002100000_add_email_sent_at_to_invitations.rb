class AddEmailSentAtToInvitations < ActiveRecord::Migration[7.2]
  # Set when InvitationMailer delivers the invitation. Only an invitation that
  # actually reached the invitee's inbox makes its token proof of email
  # ownership at sign-up (issue #106). Seats reserved without an email (e.g.
  # bulk invite) are matched by email and verified separately.
  def change
    add_column :invitations, :email_sent_at, :datetime
    # All pre-existing invitations were emailed under the old system.
    # Backfill so seat_for (which filters on email_sent_at: nil) never
    # matches them and allows token-bypass sign-up (issue #106).
    execute("UPDATE invitations SET email_sent_at = created_at")
  end
end
