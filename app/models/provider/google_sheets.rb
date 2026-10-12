require "date"
require "bigdecimal"
require "csv"
require "uri"
require "net/http"

class Provider::GoogleSheets
  class Error < StandardError; end

  TransactionRow = Struct.new(
    :date,
    :amount,
    :name,
    :currency,
    :memo,
    :category,
    :external_id,
    :pending,
    keyword_init: true
  )

  REQUIRED_COLUMNS = %w[date amount name].freeze

  def initialize(sharing_url:, default_currency: "USD")
    @sharing_url = sharing_url
    @default_currency = default_currency
  end

  def fetch_transactions
    csv_body = download_csv
    parse_transactions(csv_body)
  end

  def export_url
    uri = URI.parse(@sharing_url)
    path_match = uri.path.match(%r{/spreadsheets/d/([^/]+)/})
    raise Error, "Invalid Google Sheets URL" unless path_match

    sheet_id = path_match[1]
    params = Rack::Utils.parse_query(uri.query)
    gid = params["gid"].presence || "0"

    URI::HTTPS.build(
      host: "docs.google.com",
      path: "/spreadsheets/d/#{sheet_id}/export",
      query: "format=csv&gid=#{gid}"
    ).to_s
  rescue URI::InvalidURIError
    raise Error, "Invalid Google Sheets URL"
  end

  private

    def download_csv
      uri = URI.parse(export_url)
      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "Google Sheets export failed with status #{response.code}"
      end

      response.body
    end

    def parse_transactions(csv_body)
      rows = CSV.parse(csv_body, headers: true, return_headers: false)
      headers = normalize_headers(rows.headers)
      ensure_required_columns!(headers.values)

      rows.filter_map do |row|
        record = header_mapped_row(row, headers)
        next if row_blank?(record)
        next unless valid_row?(record)

        TransactionRow.new(
          date: Date.parse(record["date"].to_s),
          amount: BigDecimal(record["amount"].to_s),
          name: record["name"].to_s.strip,
          currency: (record["currency"].presence || @default_currency),
          memo: record["memo"].presence,
          category: record["category"].presence,
          external_id: record["external_id"].presence,
          pending: truthy?(record["pending"])
        )
      rescue ArgumentError
        nil
      end
    end

    def normalize_headers(raw_headers)
      raw_headers.index_with { |h| h.to_s.strip.downcase }
    end

    def header_mapped_row(row, headers)
      headers.to_h { |raw, normalized| [ normalized, row[raw] ] }
    end

    def ensure_required_columns!(columns)
      missing = REQUIRED_COLUMNS - columns
      raise Error, "Missing required columns: #{missing.join(", ")}" if missing.any?
    end

    def valid_row?(record)
      REQUIRED_COLUMNS.all? { |key| record[key].present? }
    end

    def row_blank?(record)
      record.values.all?(&:blank?)
    end

    def truthy?(value)
      value.to_s.strip.downcase.in?([ "true", "1", "yes", "y" ])
    end
end
