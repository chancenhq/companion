require "test_helper"

class Assistant::Function::GetMyAccountTest < ActiveSupport::TestCase
  setup do
    Setting.metabase_url = "https://metabase.example.com"
    Setting.metabase_api_key = "test-metabase-key"
    Setting.metabase_student_question_id = "42"
  end

  teardown do
    Setting.metabase_url = nil
    Setting.metabase_api_key = nil
    Setting.metabase_student_question_id = nil
  end

  test "refuses unverified users without calling Metabase" do
    Provider::MetabaseStudentAccount.any_instance.expects(:find_by_email).never

    result = Assistant::Function::GetMyAccount.new(User.create!(email: "unverified-#{SecureRandom.hex(4)}@example.com", password: "Password1!", family: families(:empty))).call

    assert_equal "email_verification_required", result[:error]
  end

  test "returns the ISA summary for verified users" do
    user = users(:sso_only)
    data = Provider::MetabaseStudentAccount::StudentAccountData.new(
      email: user.email,
      status: "repaying",
      total_financed: 1000,
      repayments_received: 250,
      max_amount: 2000,
      installments_paid: 5,
      max_installments: 48,
      currency: "KES"
    )
    Provider::MetabaseStudentAccount.any_instance.expects(:find_by_email).with(user.email).returns(data)

    result = Assistant::Function::GetMyAccount.new(user).call

    assert_equal "repaying", result[:isa_status]
  end
end
