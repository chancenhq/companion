# frozen_string_literal: true

class Api::V1::MyAccountController < Api::V1::BaseController
  before_action :ensure_read_scope

  def show
    sheet_url = Setting.chancen_student_sheet_url
    unless sheet_url.present?
      return render_json(
        { error: "not_configured", message: "Student account data is not configured on this server" },
        status: :service_unavailable
      )
    end

    provider = Provider::GoogleSheetsStudentAccount.new(sharing_url: sheet_url)
    account = provider.find_by_email(current_resource_owner.email)

    unless account
      return render_json(
        { error: "not_found", message: "No account data found for this student" },
        status: :not_found
      )
    end

    render_json({
      email:                account.email,
      status:               account.status,
      total_financed:       account.total_financed,
      repayments_received:  account.repayments_received,
      max_amount:           account.max_amount,
      installments_paid:    account.installments_paid,
      max_installments:     account.max_installments,
      currency:             account.currency
    })
  rescue Provider::GoogleSheetsStudentAccount::Error => e
    Rails.logger.error("[MyAccount] Google Sheets fetch failed: #{e.message}")
    render_json({ error: "sheet_error", message: "Unable to fetch student data" }, status: :bad_gateway)
  end
end
