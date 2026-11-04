# frozen_string_literal: true

family = Family.create!(
  name: "Companion E2E Family",
  chancen_country_code: "KE"
)

admin = User.create!(
  family: family,
  email: "companion-e2e-admin@example.com",
  password: "SecurePass123!",
  role: "admin",
  email_verified_at: Time.current
)

invitation = family.invitations.create!(
  inviter: admin,
  email: "companion-e2e-member@example.com",
  role: "member"
)

puts invitation.token
