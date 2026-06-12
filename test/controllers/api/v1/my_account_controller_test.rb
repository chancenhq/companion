# frozen_string_literal: true

require "test_helper"

class Api::V1::MyAccountControllerTest < ActionDispatch::IntegrationTest
  FAKE_SHEET_URL = "https://docs.google.com/spreadsheets/d/FAKE_ID/edit"

  STUDENT_ROW = Provider::GoogleSheetsStudentAccount::StudentAccountRow.new(
    email:               "member@example.com",
    status:              "repaying",
    total_financed:      268240.0,
    repayments_received: 45000.0,
    max_amount:          300000.0,
    installments_paid:   9,
    max_installments:    108,
    currency:            "KES"
  )

  setup do
    @user = users(:family_admin)
    @user.api_keys.active.destroy_all
    @api_key = ApiKey.create!(
      user: @user,
      name: "Test Read Key",
      scopes: [ "read" ],
      source: "web",
      display_key: "test_read_#{SecureRandom.hex(8)}"
    )
  end

  test "returns 401 without authentication" do
    get "/api/v1/my_account"
    assert_response :unauthorized
  end

  test "returns 503 when sheet URL not configured" do
    Setting.chancen_student_sheet_url = nil
    get "/api/v1/my_account", headers: { "X-Api-Key" => @api_key.plain_key }
    assert_response :service_unavailable
    assert_equal "not_configured", JSON.parse(response.body)["error"]
  end

  test "returns 404 when student not found in sheet" do
    Setting.chancen_student_sheet_url = FAKE_SHEET_URL
    Provider::GoogleSheetsStudentAccount.any_instance.stubs(:find_by_email).returns(nil)

    get "/api/v1/my_account", headers: { "X-Api-Key" => @api_key.plain_key }
    assert_response :not_found
    assert_equal "not_found", JSON.parse(response.body)["error"]
  end

  test "returns student account data when found" do
    Setting.chancen_student_sheet_url = FAKE_SHEET_URL
    Provider::GoogleSheetsStudentAccount.any_instance.stubs(:find_by_email).returns(STUDENT_ROW)

    get "/api/v1/my_account", headers: { "X-Api-Key" => @api_key.plain_key }
    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal "repaying",  body["status"]
    assert_equal 268240.0,    body["total_financed"]
    assert_equal 45000.0,     body["repayments_received"]
    assert_equal 300000.0,    body["max_amount"]
    assert_equal 9,           body["installments_paid"]
    assert_equal 108,         body["max_installments"]
    assert_equal "KES",       body["currency"]
  end

  test "returns 502 when sheet fetch fails" do
    Setting.chancen_student_sheet_url = FAKE_SHEET_URL
    Provider::GoogleSheetsStudentAccount.any_instance.stubs(:find_by_email)
      .raises(Provider::GoogleSheetsStudentAccount::Error, "HTTP 403")

    get "/api/v1/my_account", headers: { "X-Api-Key" => @api_key.plain_key }
    assert_response :bad_gateway
    assert_equal "sheet_error", JSON.parse(response.body)["error"]
  end
end
