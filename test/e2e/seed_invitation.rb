# frozen_string_literal: true

require "json"

def create_family_with_admin!(name:, email:)
  family = Family.create!(name: name, chancen_country_code: "KE")
  admin = User.create!(
    family: family,
    email: email,
    password: "SecurePass123!",
    role: "admin",
    email_verified_at: Time.current
  )

  [ family, admin ]
end

family, admin = create_family_with_admin!(
  name: "Companion E2E Family",
  email: "companion-e2e-admin@example.com"
)
signup_invitation = family.invitations.create!(
  inviter: admin,
  email: "companion-e2e-member@example.com",
  role: "member"
)

verification_family, = create_family_with_admin!(
  name: "Companion E2E Verification Family",
  email: "companion-e2e-verification-admin@example.com"
)
verification_user = User.create!(
  family: verification_family,
  email: "companion-e2e-verification@example.com",
  password: "SecurePass123!",
  role: "member"
)

reset_family, = create_family_with_admin!(
  name: "Companion E2E Reset Family",
  email: "companion-e2e-reset-admin@example.com"
)
reset_user = User.create!(
  family: reset_family,
  email: "companion-e2e-reset@example.com",
  password: "SecurePass123!",
  role: "member"
)

expired_family, expired_admin = create_family_with_admin!(
  name: "Companion E2E Expired Invitation Family",
  email: "companion-e2e-expired-admin@example.com"
)
expired_invitation = expired_family.invitations.create!(
  inviter: expired_admin,
  email: "companion-e2e-expired@example.com",
  role: "member"
)
expired_invitation.update_column(:expires_at, 1.minute.ago)

puts JSON.generate(
  signup_invitation_token: signup_invitation.token,
  email_confirmation_token: verification_user.generate_token_for(:email_confirmation),
  password_reset_token: reset_user.generate_token_for(:password_reset),
  expired_invitation_token: expired_invitation.token
)
