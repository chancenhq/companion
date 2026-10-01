# frozen_string_literal: true

require "test_helper"

class Api::V1::MyAccountControllerTest < ActionDispatch::IntegrationTest
  setup do
    @password_user = users(:family_admin)
    @sso_only_user = users(:sso_only)

    Setting.metabase_url = "https://metabase.example.com"
    Setting.metabase_api_key = "test-metabase-key"
    Setting.metabase_student_question_id = "42"
  end

  teardown do
    Setting.metabase_url = nil
    Setting.metabase_api_key = nil
    Setting.metabase_student_question_id = nil
  end

  test "requires authentication" do
    get "/api/v1/my_account"

    assert_response :unauthorized
  end

  test "unverified user gets 403 and Metabase is never called" do
    Provider::MetabaseStudentAccount.any_instance.expects(:find_by_email).never

    get "/api/v1/my_account", headers: api_headers(read_key_for(@password_user))

    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal "email_verification_required", body["error"]
    assert_equal "resend_email", body["action"]
  end

  test "sso-only user gets their ISA summary" do
    data = Provider::MetabaseStudentAccount::StudentAccountData.new(
      email: @sso_only_user.email,
      status: "repaying",
      total_financed: 1000,
      repayments_received: 250,
      max_amount: 2000,
      installments_paid: 5,
      max_installments: 48,
      currency: "KES"
    )
    Provider::MetabaseStudentAccount.any_instance.expects(:find_by_email).with(@sso_only_user.email).returns(data)

    get "/api/v1/my_account", headers: api_headers(read_key_for(@sso_only_user))

    assert_response :ok
    assert_equal "repaying", JSON.parse(response.body)["status"]
  end

  private

    def read_key_for(user)
      user.api_keys.active.destroy_all
      ApiKey.create!(
        user: user,
        name: "Test Read Key",
        scopes: [ "read" ],
        source: "web",
        display_key: "test_read_#{SecureRandom.hex(8)}"
      )
    end

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
