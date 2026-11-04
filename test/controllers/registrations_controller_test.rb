require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_url
    assert_response :success
  end

  test "create redirects to correct URL" do
    post registration_url, params: { user: {
      email: "john@example.com",
      password: "Password1!" } }

    assert_redirected_to root_url
  end

  test "create rolls back registration when session creation fails" do
    RegistrationsController.any_instance.stubs(:create_session_for).returns(false)

    assert_no_difference "User.count" do
      post registration_url, params: { user: {
        email: "session-failure@example.com",
        password: "Password1!" } }
    end

    assert_response :unprocessable_entity
    assert_nil User.find_by(email: "session-failure@example.com")
  end

  test "first user of instance becomes super_admin" do
    # Clear all users to simulate fresh instance
    User.connection.disable_referential_integrity { User.delete_all }

    assert_difference "User.count", +1 do
      post registration_url, params: { user: {
        email: "firstuser@example.com",
        password: "Password1!" } }
    end

    first_user = User.find_by(email: "firstuser@example.com")
    assert first_user.super_admin?, "First user should be super_admin"
  end

  test "subsequent users become admin not super_admin" do
    # Ensure users exist from fixtures
    assert User.exists?

    assert_difference "User.count", +1 do
      post registration_url, params: { user: {
        email: "seconduser@example.com",
        password: "Password1!" } }
    end

    new_user = User.find_by(email: "seconduser@example.com")
    assert new_user.admin?, "Subsequent user should be admin"
    assert_not new_user.super_admin?, "Subsequent user should not be super_admin"
  end

  test "create when hosted requires an invite code" do
    with_env_overrides REQUIRE_INVITE_CODE: "true" do
      assert_no_difference "User.count" do
        post registration_url, params: { user: {
          email: "john@example.com",
          password: "Password1!" } }
        assert_redirected_to new_registration_url

        post registration_url, params: { user: {
          email: "john@example.com",
          password: "Password1!",
          invite_code: "foo" } }
        assert_redirected_to new_registration_url
      end

      assert_difference "User.count", +1 do
        invite_code = InviteCode.generate!
        post registration_url, params: { user: {
          email: "john@example.com",
          password: "Password1!",
          invite_code: invite_code } }
        assert_redirected_to root_url
        assert_not InviteCode.exists?(token: invite_code)
      end
    end
  end

  test "invite code is not consumed when signup fails validation" do
    with_env_overrides REQUIRE_INVITE_CODE: "true" do
      invite_code = InviteCode.generate!

      assert_no_difference "User.count" do
        post registration_url, params: { user: {
          email: "validationfail@example.com",
          password: "weak",
          invite_code: invite_code } }
      end

      assert_response :unprocessable_entity
      assert InviteCode.exists?(token: invite_code)
    end
  end

  test "invalid invite code does not create a user" do
    with_env_overrides REQUIRE_INVITE_CODE: "true" do
      assert_no_difference "User.count" do
        post registration_url, params: { user: {
          email: "valid@example.com",
          password: "Password1!",
          invite_code: "invalid-token-that-does-not-exist" } }
      end

      assert_redirected_to new_registration_url
    end
  end

  test "creating account from guest invitation assigns guest role and intro layout" do
    invitation = invitations(:one)
    invitation.update!(role: "guest", email: "guest-signup@example.com")

    assert_difference "User.count", +1 do
      post registration_url, params: { user: {
        email: invitation.email,
        password: "Password1!",
        invitation: invitation.token
      } }
    end

    created_user = User.find_by(email: invitation.email)
    assert_equal "guest", created_user.role
    assert created_user.ui_layout_intro?
    assert_not created_user.show_sidebar?
    assert_not created_user.show_ai_sidebar?
    assert created_user.ai_enabled?
  end

  test "creating account from invitation shares existing family accounts when family shares by default" do
    invitation = invitations(:one)
    invitation.family.update!(default_account_sharing: "shared")

    post registration_url, params: { user: {
      email: invitation.email,
      password: "Password1!",
      invitation: invitation.token
    } }

    created_user = User.find_by(email: invitation.email)
    assert_not_nil created_user
    assert_equal invitation.family_id, created_user.family_id
    assert_equal invitation.family.accounts.pluck(:id).sort,
      AccountShare.where(user: created_user).pluck(:account_id).sort
  end

  # Chancen invite-only (issue #106) is strict: a configured default family does
  # not create a self-service seat. Only a pending invitation (emailed token or a
  # provider-verified email match) admits a new account. Mirrors the mobile-path
  # assertion in Api::V1::AuthControllerTest "signup does not join the invite-only
  # default family without an invitation".
  test "invite_only rejects self-service sign-up even when a default family is configured" do
    family = families(:dylan_family)
    family.update!(default_account_sharing: "shared")
    Setting.onboarding_state = "invite_only"
    Setting.invite_only_default_family_id = family.id

    assert_no_difference "User.count" do
      post registration_url, params: { user: {
        email: "default-family-signup@example.com",
        password: "Password1!"
      } }
    end

    assert_redirected_to new_session_url
    assert_equal "Sign-up is by invitation only. Use the email address you gave Chancen.", flash[:alert]
    assert_nil User.find_by(email: "default-family-signup@example.com")
  end

  test "creating account from invitation shares nothing when family sharing is private" do
    invitation = invitations(:one)
    invitation.family.update!(default_account_sharing: "private")

    post registration_url, params: { user: {
      email: invitation.email,
      password: "Password1!",
      invitation: invitation.token
    } }

    created_user = User.find_by(email: invitation.email)
    assert_not_nil created_user
    assert_equal 0, AccountShare.where(user: created_user).count
  end
  test "invite_only blocks sign-up without an invitation in managed mode" do
    with_onboarding_state("invite_only") do
      # The form stays reachable: the seat is matched by email on submit.
      get new_registration_url
      assert_response :success

      assert_no_difference "User.count" do
        post registration_url, params: { user: { email: "uninvited@example.com", password: "Password1!" } }
      end
      assert_redirected_to new_session_url
      assert_equal "Sign-up is by invitation only. Use the email address you gave Chancen.", flash[:alert]
    end
  end

  test "invite_only web sign-up takes the seat reserved for that email and starts unverified" do
    invitation = invitations(:one)

    with_onboarding_state("invite_only") do
      assert_enqueued_emails 1 do
        post registration_url, params: { user: { email: invitation.email, password: "Password1!" } }
      end
    end

    user = User.find_by!(email: invitation.email)
    assert_equal invitation.family, user.family
    assert_not user.email_verified?
  end

  test "invite_only allows sign-up with an invitation token" do
    invitation = invitations(:one)

    with_onboarding_state("invite_only") do
      get new_registration_url(invitation: invitation.token)
      assert_response :success

      assert_difference "User.count", +1 do
        post registration_url, params: { user: {
          email: invitation.email,
          password: "Password1!",
          invitation: invitation.token } }
      end
      assert_not_nil invitation.reload.accepted_at
    end
  end

  test "web sign-up with an invitation gives the new user the invitation's country" do
    invitation = invitations(:one)
    invitation.update_column(:country_code, "RW")

    with_onboarding_state("invite_only") do
      post registration_url, params: { user: {
        email: invitation.email,
        password: "Password1!",
        invitation: invitation.token } }
    end

    assert_equal "RW", User.find_by!(email: invitation.email).country_code
  end

  test "closed blocks sign-up even with an invitation token" do
    invitation = invitations(:one)

    with_onboarding_state("closed") do
      assert_no_difference "User.count" do
        post registration_url, params: { user: {
          email: invitation.email,
          password: "Password1!",
          invitation: invitation.token } }
      end
      assert_redirected_to new_session_url
      assert_equal "Signups are currently closed.", flash[:alert]
    end
  end

  test "web sign-up without an invitation sends a verification email" do
    assert_enqueued_emails 1 do
      post registration_url, params: { user: { email: "web-verify@example.com", password: "Password1!" } }
    end

    assert_not User.find_by!(email: "web-verify@example.com").email_verified?
  end

  test "web sign-up with the token from an emailed invitation is verified at once" do
    invitation = invitations(:one)
    invitation.update!(email_sent_at: 1.day.ago)

    post registration_url, params: { user: { email: invitation.email, password: "Password1!", invitation: invitation.token } }

    assert User.find_by!(email: invitation.email).email_verified?
  end

  test "web sign-up without a token does not claim an invitation that was emailed" do
    invitation = invitations(:one)
    invitation.update!(email_sent_at: 1.day.ago)

    post registration_url, params: { user: { email: invitation.email, password: "Password1!" } }

    user = User.find_by!(email: invitation.email)
    assert_not_equal invitation.family, user.family
    assert_nil invitation.reload.accepted_at
  end

  test "web sign-up without a token takes a seat that was never emailed" do
    invitation = invitations(:one)

    post registration_url, params: { user: { email: invitation.email, password: "Password1!" } }

    user = User.find_by!(email: invitation.email)
    assert_equal invitation.family, user.family
    assert_not user.email_verified?
  end

  private

    def with_onboarding_state(state)
      original = Setting.onboarding_state
      Setting.onboarding_state = state
      yield
    ensure
      Setting.onboarding_state = original
    end
end
