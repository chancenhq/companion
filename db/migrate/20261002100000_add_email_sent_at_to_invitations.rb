class AddEmailSentAtToInvitations < ActiveRecord::Migration[7.2]
  # Set when InvitationMailer delivers the invitation. Only an invitation that
  # actually reached the invitee's inbox makes its token proof of email
  # ownership at sign-up (issue #106). Seats reserved without an email (e.g.
  # bulk invite) are matched by email and verified separately.
  def change
    add_column :invitations, :email_sent_at, :datetime
  end
end
