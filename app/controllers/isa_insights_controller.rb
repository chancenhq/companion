class IsaInsightsController < ApplicationController
  ISA_STATUS_PATTERNS = {
    /isa contract signed|contract_signed|contract signed/ => :contract_signed,
    /graduated/                                           => :graduated,
    /drop[\s_]?out|dropout/                              => :dropped_out
  }.freeze

  def show
    url         = Setting.metabase_url.presence
    api_key     = Setting.metabase_api_key.presence
    question_id = Setting.metabase_student_question_id.presence

    unless url && api_key && question_id
      @isa_status = :unconfigured
      return
    end

    provider = Provider::MetabaseStudentAccount.new(
      url:         url,
      api_key:     api_key,
      question_id: question_id,
      email_param: Setting.metabase_email_param.presence || "email"
    )

    @account    = provider.find_by_email(Current.user.email)
    @isa_status = @account ? resolve_isa_status(@account.status) : :not_found
  rescue Provider::MetabaseStudentAccount::Error
    @isa_status = :unavailable
  end

  private

    def resolve_isa_status(status_string)
      normalized = status_string.to_s.downcase.strip
      ISA_STATUS_PATTERNS.each { |pattern, status| return status if normalized.match?(pattern) }
      :application
    end
end
