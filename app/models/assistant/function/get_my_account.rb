class Assistant::Function::GetMyAccount < Assistant::Function
  class << self
    def name
      "get_my_account"
    end

    def description
      "Returns the student's ISA account summary from the Chancen data warehouse: ISA status, total amount financed, repayments received so far, maximum repayment cap, and instalment progress. Call this when the student asks about their ISA status, how much they've been financed, or their repayment progress."
    end
  end

  def call(_params = {})
    url         = Setting.metabase_url.presence
    api_key     = Setting.metabase_api_key.presence
    question_id = Setting.metabase_student_question_id.presence

    return { error: "ISA account data is not configured" } unless url && api_key && question_id

    provider = Provider::MetabaseStudentAccount.new(
      url:         url,
      api_key:     api_key,
      question_id: question_id,
      email_param: Setting.metabase_email_param.presence || "email"
    )

    data = provider.find_by_email(user.email)
    return { error: "No ISA record found for this account" } unless data

    {
      isa_status:           data.status,
      total_financed:       data.total_financed,
      repayments_received:  data.repayments_received,
      max_repayment_amount: data.max_amount,
      installments_paid:    data.installments_paid,
      max_installments:     data.max_installments,
      currency:             data.currency
    }
  rescue Provider::MetabaseStudentAccount::Error => e
    { error: "Unable to retrieve ISA account data: #{e.message}" }
  end

  private

    def build_schema(...)
      super(properties: {}, required: [])
    end
end
