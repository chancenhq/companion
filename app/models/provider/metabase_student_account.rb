class Provider::MetabaseStudentAccount < Provider
  Error = Class.new(Provider::Error)

  StudentAccountData = Data.define(
    :email,
    :status,
    :total_financed,
    :repayments_received,
    :max_amount,
    :installments_paid,
    :max_installments,
    :currency
  )

  def initialize(url:, api_key:, question_id:, email_param: "email")
    @url         = url.chomp("/")
    @api_key     = api_key
    @question_id = question_id
    @email_param = email_param
  end

  def find_by_email(email)
    response = connection.post(
      "/api/card/#{@question_id}/query",
      {
        parameters: [ {
          type:   "text",
          target: [ "variable", [ "template-tag", "email" ] ],
          value:  email.downcase
        } ]
      }.to_json,
      { "Content-Type" => "application/json", "X-API-KEY" => @api_key }
    )

    raise Error, "Metabase returned #{response.status}" unless response.success?

    body = JSON.parse(response.body)
    cols = body.dig("data", "cols")&.map { |c| c["name"] } || []
    row  = body.dig("data", "rows")&.first
    return nil unless row

    def_at = ->(col) { idx = cols.index(col); idx && row[idx] }

    StudentAccountData.new(
      email:               strip_pii(def_at.("email")).to_s,
      status:              def_at.("isa_status").to_s,
      total_financed:      def_at.("total_financed")&.to_f,
      repayments_received: def_at.("total_repayments")&.to_f,
      max_amount:          def_at.("total_financed")&.to_f,
      installments_paid:   nil,
      max_installments:    nil,
      currency:            "KES"
    )
  rescue Faraday::Error => e
    raise Error, "Metabase connection error: #{e.message}"
  end

  private

    def strip_pii(value)
      value.to_s.sub(/\A<TODO-MASK-PII>/i, "").downcase
    end

    def connection
      raise Error, "Metabase URL must use HTTPS" unless @url.start_with?("https://")
      @connection ||= Faraday.new(url: @url) do |f|
        f.request :retry, max: 2, interval: 0.5
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end
end
