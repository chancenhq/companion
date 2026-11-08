require "test_helper"

class EmailConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test "confirming an email change signs the user in" do
    user = users(:new_email)
    user.update!(unconfirmed_email: "new@example.com")
    token = user.generate_token_for(:email_confirmation)

    get new_email_confirmation_path(token: token)
    assert_redirected_to new_session_path
  end

  test "verifying a new account renders the confirmation page" do
    user = users(:unverified)
    token = user.generate_token_for(:email_confirmation)

    get new_email_confirmation_path(token: token)

    assert_response :success
    assert user.reload.email_verified?
    assert_select "span.translation_missing", false
    assert_select "h1", I18n.t("email_confirmations.verified.title")
    assert_match I18n.t("email_confirmations.verified.body"), response.body
  end

  test "an invalid token renders the invalid page" do
    get new_email_confirmation_path(token: "not-a-real-token")

    assert_response :unprocessable_entity
    assert_select "span.translation_missing", false
    assert_select "h1", I18n.t("email_confirmations.invalid.title")
    assert_match I18n.t("email_confirmations.invalid.body"), response.body
  end
end
