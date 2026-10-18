require "test_helper"

class Assistant::Function::GetISATransactionsTest < ActiveSupport::TestCase
  setup do
    Setting.metabase_url = "https://metabase.example.com"
    Setting.metabase_api_key = "test-metabase-key"
    Setting.metabase_transactions_question_id = "43"
  end

  teardown do
    Setting.metabase_url = nil
    Setting.metabase_api_key = nil
    Setting.metabase_transactions_question_id = nil
  end

  test "refuses unverified users without calling Metabase" do
    Provider::MetabaseStudentTransactions.any_instance.expects(:find_by_email).never

    result = Assistant::Function::GetISATransactions.new(User.create!(email: "unverified-#{SecureRandom.hex(4)}@example.com", password: "Password1!", family: families(:empty))).call

    assert_equal "email_verification_required", result[:error]
  end

  test "returns the ISA payment history for verified users" do
    user = users(:sso_only)
    transaction = Provider::MetabaseStudentTransactions::TransactionData.new(
      payment_type: "repayment",
      amount: 100,
      currency: "KES",
      payment_date: "2026-09-01"
    )
    Provider::MetabaseStudentTransactions.any_instance.expects(:find_by_email).with(user.email).returns([ transaction ])

    result = Assistant::Function::GetISATransactions.new(user).call

    assert_equal 1, result[:total]
  end
end
