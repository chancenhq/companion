# frozen_string_literal: true

class SheetInsightsFetcher
  Error              = Class.new(StandardError)
  NotFoundError      = Class.new(Error)
  ConfigurationError = Class.new(Error)

  CACHE_TTL    = 23.hours
  EMAIL_COLUMN = "Email"

  FIELDS = {
    "ISA Status"              => :isa_status,
    "Total Financed"          => :total_financed,
    "Repayment Percentage"    => :repayment_percentage,
    "Maximum Financed Amount" => :maximum_financed_amount,
    "Total Repaid So Far"     => :total_repaid_so_far,
    "installments_paid"       => :installments_paid,
    "Max Installments"        => :max_installments,
    "Currency"                => :currency,
    "Institution"             => :institution
  }.freeze

  def initialize
    raise ConfigurationError, "GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON not set" unless ENV["GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON"].present?
    raise ConfigurationError, "No GOOGLE_SHEETS_SPREADSHEET_ID_* env vars set" if spreadsheet_ids.empty?
  end

  def fetch_for_email(email)
    spreadsheet_ids.each do |country, sheet_id|
      rows = cached_rows(country, sheet_id)
      row  = rows.find { |r| r[EMAIL_COLUMN]&.strip&.downcase == email.strip.downcase }
      next unless row
      return FIELDS.each_with_object({}) { |(col, key), h| h[key] = row[col] }
    end
    raise NotFoundError, "No ISA data found for #{email}"
  end

  private

    def spreadsheet_ids
      ENV.select { |k, _| k.start_with?("GOOGLE_SHEETS_SPREADSHEET_ID_") }
         .transform_keys { |k| k.delete_prefix("GOOGLE_SHEETS_SPREADSHEET_ID_").downcase }
    end

    def cached_rows(country, sheet_id)
      Rails.cache.fetch("sheet_insights_rows_#{country}", expires_in: CACHE_TTL) { fetch_rows(sheet_id) }
    end

    def fetch_rows(sheet_id)
      range   = sheets_service.get_spreadsheet_values(sheet_id, "A:Z")
      values  = range.values || []
      headers = values.first || []
      values[1..].map { |row| headers.zip(row).to_h }
    rescue Google::Apis::Error => e
      raise Error, "Google Sheets API error: #{e.message}"
    end

    def sheets_service
      @sheets_service ||= begin
        credentials = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: StringIO.new(ENV["GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON"]),
          scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY
        )
        Google::Apis::SheetsV4::SheetsService.new.tap { |s| s.authorization = credentials }
      rescue MultiJson::ParseError, JSON::ParserError => e
        raise ConfigurationError, "GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON is not valid JSON: #{e.message}"
      rescue OpenSSL::PKey::PKeyError => e
        raise ConfigurationError, "GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON private_key is invalid: #{e.message}"
      end
    end
end
