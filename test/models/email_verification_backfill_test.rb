require "test_helper"
require Rails.root.join("db/migrate/20261002090000_add_email_verified_at_to_users")

# The one-off backfill decides which existing accounts count as verified when
# issue #106 ships. It must trust only accounts whose email a trusted provider
# proved AND where nobody else can hold a password.
class EmailVerificationBackfillTest < ActiveSupport::TestCase
  setup do
    User.update_all(email_verified_at: nil)
  end

  test "Google/Apple-only accounts are verified" do
    google = account(password: nil, identity: { provider: "google_oauth2" })
    apple = account(password: nil, identity: { provider: "apple" })
    google_oidc = account(password: nil, identity: { provider: "openid_connect", issuer: "https://accounts.google.com" })

    run_backfill

    assert google.reload.email_verified?
    assert apple.reload.email_verified?
    assert google_oidc.reload.email_verified?
  end

  test "Google sign-up with a backup password is verified" do
    user = account(password: "Password1!", identity: { provider: "google_oauth2", after: 5.seconds })

    run_backfill

    assert user.reload.email_verified?
  end

  test "password accounts that linked Google/Apple later stay unverified" do
    user = account(password: "Password1!", identity: { provider: "google_oauth2", after: 2.days })

    run_backfill

    assert_not user.reload.email_verified?
  end

  test "password-only and untrusted-provider accounts stay unverified" do
    password_only = account(password: "Password1!")
    github_only = account(password: nil, identity: { provider: "github" })
    generic_oidc = account(password: nil, identity: { provider: "openid_connect", issuer: "https://idp.example.com" })

    run_backfill

    assert_not password_only.reload.email_verified?
    assert_not github_only.reload.email_verified?
    assert_not generic_oidc.reload.email_verified?
  end

  private

    def run_backfill
      ActiveRecord::Base.connection.execute(AddEmailVerifiedAtToUsers.new.backfill_sql)
    end

    def account(password:, identity: nil)
      user = User.create!(
        email: "backfill-#{SecureRandom.hex(4)}@example.com",
        password: password,
        skip_password_validation: password.nil?,
        family: families(:empty)
      )
      user.update_columns(created_at: 3.days.ago, email_verified_at: nil)

      if identity
        record = OidcIdentity.create!(
          user: user,
          provider: identity[:provider],
          uid: SecureRandom.hex(8),
          issuer: identity[:issuer],
          info: { email: user.email }
        )
        record.update_columns(created_at: user.created_at + identity.fetch(:after, 0.seconds))
      end

      user
    end
end
