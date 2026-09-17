require "test_helper"

class Provider::GoogleSheetsTest < ActiveSupport::TestCase
  test "builds csv export url from sharing link" do
    provider = Provider::GoogleSheets.new(
      sharing_url: "https://docs.google.com/spreadsheets/d/abc123/edit?gid=987"
    )

    assert_equal "https://docs.google.com/spreadsheets/d/abc123/export?format=csv&gid=987", provider.export_url
  end

  test "parses transactions and skips invalid rows" do
    provider = Provider::GoogleSheets.new(
      sharing_url: "https://docs.google.com/spreadsheets/d/abc123/edit?gid=0"
    )

    csv = <<~CSV
      date,amount,name,currency,pending
      2026-01-02,-12.55,Coffee Shop,USD,true
      ,12.55,Missing Date,USD,false
      2026-01-03,40.00,Refund,,0
    CSV

    rows = provider.send(:parse_transactions, csv)

    assert_equal 2, rows.count
    assert_equal "Coffee Shop", rows.first.name
    assert_equal BigDecimal("-12.55"), rows.first.amount
    assert_equal true, rows.first.pending
    assert_equal "USD", rows.last.currency
    assert_equal false, rows.last.pending
  end
end
