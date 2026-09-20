class Api::V1::MyAccountTransactionsController < Api::V1::BaseController
  before_action :ensure_read_scope

  def index
    url         = Setting.metabase_url.presence
    api_key     = Setting.metabase_api_key.presence
    question_id = Setting.metabase_transactions_question_id.presence

    unless url && api_key && question_id
      return render json: { error: "service_unavailable", message: "Student transaction data is not configured" }, status: :service_unavailable
    end

    provider = Provider::MetabaseStudentTransactions.new(
      url:         url,
      api_key:     api_key,
      question_id: question_id,
      email_param: Setting.metabase_email_param.presence || "email"
    )

    transactions = provider.find_by_email(current_resource_owner.email)

    render json: transactions.map { |t|
      { payment_type: t.payment_type, amount: t.amount, currency: t.currency, payment_date: t.payment_date }
    }
  rescue Provider::MetabaseStudentTransactions::Error => e
    Rails.logger.error "MetabaseStudentTransactions error: #{e.message}"
    render json: { error: "upstream_error", message: "Unable to retrieve student transactions" }, status: :bad_gateway
  end
end
