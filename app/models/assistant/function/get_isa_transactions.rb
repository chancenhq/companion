class Assistant::Function::GetISATransactions < Assistant::Function
  class << self
    def name
      "get_isa_transactions"
    end

    def description
      "Returns the student's ISA payment history from the Chancen data warehouse: a list of payments made toward their ISA, including repayments and commitment fees. Call this when the student asks about their payment history, past repayments, or how much they've paid in a given period."
    end
  end

  def call(_params = {})
    url         = Setting.metabase_url.presence
    api_key     = Setting.metabase_api_key.presence
    question_id = Setting.metabase_transactions_question_id.presence

    return { error: "ISA transaction data is not configured" } unless url && api_key && question_id

    provider = Provider::MetabaseStudentTransactions.new(
      url:         url,
      api_key:     api_key,
      question_id: question_id,
      email_param: Setting.metabase_email_param.presence || "email"
    )

    transactions = provider.find_by_email(user.email)

    {
      total: transactions.size,
      transactions: transactions.map { |t|
        { payment_type: t.payment_type, amount: t.amount, currency: t.currency, payment_date: t.payment_date }
      }
    }
  rescue Provider::MetabaseStudentTransactions::Error => e
    { error: "Unable to retrieve ISA transactions: #{e.message}" }
  end

  private

    def build_schema(...)
      super(properties: {}, required: [])
    end
end
