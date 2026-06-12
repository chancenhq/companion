# frozen_string_literal: true

require "csv"
require "uri"
require "net/http"

class Provider::GoogleSheetsStudentAccount
  class Error < StandardError; end

  DEFAULT_CURRENCY = "KES"

  REQUIRED_COLUMNS = %w[email status total_financed repayments_received max_amount installments_paid max_installments].freeze

  StudentAccountRow = Struct.new(
    :email,
    :status,
    :total_financed,
    :repayments_received,
    :max_amount,
    :installments_paid,
    :max_installments,
    :currency,
    keyword_init: true
  )

  def initialize(sharing_url:)
    @sharing_url = sharing_url
  end

  def find_by_email(email)
    csv_body = download_csv
    parse_student_row(csv_body, email.to_s.strip.downcase)
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
      response = fetch_with_redirects(uri)
      raise Error, "Google Sheets export failed with status #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      response.body
    end

    def fetch_with_redirects(uri, limit = 5)
      raise Error, "Too many redirects" if limit.zero?

      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPRedirection)
        fetch_with_redirects(URI.parse(response["location"]), limit - 1)
      else
        response
      end
    end

    def parse_student_row(csv_body, target_email)
      rows = CSV.parse(csv_body, headers: true, return_headers: false)
      headers = normalize_headers(rows.headers)
      ensure_required_columns!(headers.values)

      rows.each do |row|
        record = header_mapped_row(row, headers)
        next if record["email"].to_s.strip.downcase != target_email

        return StudentAccountRow.new(
          email:                record["email"].to_s.strip.downcase,
          status:               record["status"].to_s.strip.downcase,
          total_financed:       record["total_financed"].to_f,
          repayments_received:  record["repayments_received"].to_f,
          max_amount:           record["max_amount"].to_f,
          installments_paid:    record["installments_paid"].to_i,
          max_installments:     record["max_installments"].to_i,
          currency:             record["currency"].presence&.upcase || DEFAULT_CURRENCY
        )
      end

      nil
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
end
