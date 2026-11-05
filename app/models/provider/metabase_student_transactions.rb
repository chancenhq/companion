class Provider::MetabaseStudentTransactions < Provider
  Error = Class.new(Provider::Error)

  TransactionData = Data.define(:payment_type, :amount, :currency, :payment_date)

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
          id:     email_tag_uuid,
          type:   "text",
          target: [ "variable", [ "template-tag", @email_param ] ],
          value:  email.downcase
        } ]
      }.to_json,
      { "Content-Type" => "application/json", "X-API-KEY" => @api_key }
    )

    raise Error, "Metabase returned #{response.status}" unless response.success?

    body = JSON.parse(response.body)
    cols = body.dig("data", "cols")&.map { |c| c["name"] } || []
    rows = body.dig("data", "rows") || []

    rows.map do |row|
      def_at = ->(col) { idx = cols.index(col); idx && row[idx] }

      TransactionData.new(
        payment_type: def_at.("payment_type").to_s,
        amount:       def_at.("amount")&.to_f || 0.0,
        currency:     def_at.("currency").to_s,
        payment_date: def_at.("payment_date").to_s
      )
    end
  rescue Faraday::Error => e
    body = e.response&.dig(:body).presence || "no body"
    raise Error, "Metabase connection error: #{e.message} | body: #{body}"
  end

  private

    def email_tag_uuid
      @email_tag_uuid ||= begin
        card = JSON.parse(
          connection.get("/api/card/#{@question_id}") { |req| req.headers["X-API-KEY"] = @api_key }.body
        )
        tags = card.dig("dataset_query", "stages", 0, "template-tags") ||
               card.dig("dataset_query", "native", "template-tags")
        tag  = case tags
        when Hash  then tags[@email_param]
        when Array then tags.find { |t| t["name"] == @email_param }
        end
        tag&.fetch("id") or raise Error, "Could not resolve template tag UUID for '#{@email_param}'"
      end
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
