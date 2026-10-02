require "test_helper"

class EmailConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test "should get confirm" do
    user = users(:new_email)
    user.update!(unconfirmed_email: "new@example.com")
    token = user.generate_token_for(:email_confirmation)

    get new_email_confirmation_path(token: token)
    assert_redirected_to new_session_path
  end

  test "confirmation link verifies a new account" do
    user = users(:unverified)

    get new_email_confirmation_path(token: user.generate_token_for(:email_confirmation))

    assert_redirected_to new_session_path
    assert user.reload.email_verified?
  end

  test "a used confirmation link is rejected" do
    user = users(:unverified)
    token = user.generate_token_for(:email_confirmation)
    get new_email_confirmation_path(token: token)

    get new_email_confirmation_path(token: token)

    assert_redirected_to root_path
  end

  test "a failed email change does not report success" do
    user = users(:new_email)
    user.update_column(:unconfirmed_email, users(:family_admin).email) # already taken
    token = user.generate_token_for(:email_confirmation)

    get new_email_confirmation_path(token: token)

    assert_redirected_to root_path
    assert_not_equal users(:family_admin).email, user.reload.email
  end
end
