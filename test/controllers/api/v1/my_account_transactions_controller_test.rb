# frozen_string_literal: true

require "test_helper"

class Api::V1::MyAccountTransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # A password account nobody has verified: unverified under the interim
    # rule and under #106's email_verified_at alike.
    @password_user = User.create!(email: "unverified-#{SecureRandom.hex(4)}@example.com", password: "Password1!", family: families(:empty))
    @sso_only_user = users(:sso_only)

    Setting.metabase_url = "https://metabase.example.com"
    Setting.metabase_api_key = "test-metabase-key"
    Setting.metabase_transactions_question_id = "43"
  end

  teardown do
    Setting.metabase_url = nil
    Setting.metabase_api_key = nil
    Setting.metabase_transactions_question_id = nil
  end

  test "requires authentication" do
    get "/api/v1/my_account_transactions"

    assert_response :unauthorized
  end

  test "unverified user gets 403 and Metabase is never called" do
    Provider::MetabaseStudentTransactions.any_instance.expects(:find_by_email).never

    get "/api/v1/my_account_transactions", headers: api_headers(read_key_for(@password_user))

    assert_response :forbidden
    assert_equal "email_verification_required", JSON.parse(response.body)["error"]
  end

  test "sso-only user gets their ISA payment history" do
    transaction = Provider::MetabaseStudentTransactions::TransactionData.new(
      payment_type: "repayment",
      amount: 100,
      currency: "KES",
      payment_date: "2026-09-01"
    )
    Provider::MetabaseStudentTransactions.any_instance.expects(:find_by_email).with(@sso_only_user.email).returns([ transaction ])

    get "/api/v1/my_account_transactions", headers: api_headers(read_key_for(@sso_only_user))

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 1, body.size
    assert_equal "repayment", body.first["payment_type"]
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
