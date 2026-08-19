class Api::V1::MyAccountController < Api::V1::BaseController
  before_action :ensure_read_scope

  def show
    url         = Setting.metabase_url.presence
    api_key     = Setting.metabase_api_key.presence
    question_id = Setting.metabase_student_question_id.presence

    unless url && api_key && question_id
      return render json: { error: "service_unavailable", message: "Student account data is not configured" }, status: :service_unavailable
    end

    email_param = Setting.metabase_email_param.presence || "email"

    provider = Provider::MetabaseStudentAccount.new(
      url:         url,
      api_key:     api_key,
      question_id: question_id,
      email_param: email_param
    )

    data = provider.find_by_email(current_resource_owner.email)

    return render json: { error: "not_found", message: "No ISA record found for this account" }, status: :not_found unless data

    render json: {
      email:                data.email,
      status:               data.status,
      total_financed:       data.total_financed,
      repayments_received:  data.repayments_received,
      max_amount:           data.max_amount,
      installments_paid:    data.installments_paid,
      max_installments:     data.max_installments,
      currency:             data.currency
    }
  rescue Provider::MetabaseStudentAccount::Error => e
    Rails.logger.error "MetabaseStudentAccount error: #{e.message}"
    render json: { error: "upstream_error", message: "Unable to retrieve student data" }, status: :bad_gateway
  end
end
