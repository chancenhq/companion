require "test_helper"

class EmailConfirmationMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers
  test "signup verification email uses the verify subject, body and CTA" do
    user = users(:unverified)
    assert_not user.pending_email_change?

    mail = EmailConfirmationMailer.with(user: user).confirmation_email

    assert_equal [ user.email ], mail.to
    assert_equal [ "hello@example.com" ], mail.from
    assert_equal I18n.t("email_confirmation_mailer.confirmation_email.verify_subject"), mail.subject

    verify_body = I18n.t("email_confirmation_mailer.confirmation_email.verify_body")
    verify_cta = I18n.t("email_confirmation_mailer.confirmation_email.verify_cta")
    change_body = I18n.t("email_confirmation_mailer.confirmation_email.body")
    expiry = I18n.t("email_confirmation_mailer.confirmation_email.expiry_notice", hours: 24)

    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.decoded
      assert_match verify_body, body
      assert_match verify_cta, body
      assert_no_match(/translation missing/, body)
      assert_no_match(/#{Regexp.escape(change_body)}/, body)
      assert_match expiry, body
      assert_match new_email_confirmation_path, body
    end
  end

  test "email change confirmation uses the change subject, body and CTA and targets the pending address" do
    user = users(:new_email)
    assert user.pending_email_change?

    mail = EmailConfirmationMailer.with(user: user).confirmation_email

    assert_equal [ user.unconfirmed_email ], mail.to
    assert_equal [ "hello@example.com" ], mail.from
    assert_equal I18n.t("email_confirmation_mailer.confirmation_email.subject", product_name: Rails.configuration.x.product_name), mail.subject

    change_body = I18n.t("email_confirmation_mailer.confirmation_email.body")
    change_cta = I18n.t("email_confirmation_mailer.confirmation_email.cta")
    verify_body = I18n.t("email_confirmation_mailer.confirmation_email.verify_body")
    expiry = I18n.t("email_confirmation_mailer.confirmation_email.expiry_notice", hours: 24)

    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.decoded
      assert_match change_body, body
      assert_match change_cta, body
      assert_no_match(/translation missing/, body)
      assert_no_match(/#{Regexp.escape(verify_body)}/, body)
      assert_match expiry, body
      assert_match new_email_confirmation_path, body
    end
  end
end
