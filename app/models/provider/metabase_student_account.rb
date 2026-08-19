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
    # Question #1329 has no template-tag parameters defined (it's a flat, hardcoded
    # SQL query) — posting a `parameters` entry against a nonexistent template tag
    # makes Metabase 500. We fetch the full result set and filter client-side instead.
    response = connection.post(
      "/api/card/#{@question_id}/query",
      { parameters: [] }.to_json,
      { "Content-Type" => "application/json", "X-API-KEY" => @api_key }
    )

    raise Error, "Metabase returned #{response.status}" unless response.success?

    body = JSON.parse(response.body)
    cols = body.dig("data", "cols")&.map { |c| c["name"] } || []
    rows = body.dig("data", "rows") || []

    email_index = cols.index(@email_param)
    return nil unless email_index

    # Strip the <TODO-MASK-PII> prefix Metabase adds to sensitive columns (some
    # environments mask email values this way; plain values pass through untouched)
    row = rows.find { |r| strip_pii(r[email_index]) == email.downcase }
    return nil unless row

    def_at = ->(col) { idx = cols.index(col); idx && row[idx] }

    StudentAccountData.new(
      email:               strip_pii(def_at.(@email_param)).to_s,
      status:              def_at.("ISA Status").to_s,
      total_financed:      def_at.("Maximum Funding Amount")&.to_f,
      # Not currently returned by question #1329 — awaiting a SQL update to include
      # repayment/installment data. nil (not 0) so the client can show "unavailable".
      repayments_received: nil,
      max_amount:          def_at.("Maximum Funding Amount")&.to_f,
      installments_paid:   nil,
      max_installments:    def_at.("Contract period")&.to_i,
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
      @connection ||= Faraday.new(url: @url) do |f|
        f.request :retry, max: 2, interval: 0.5
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end
end
