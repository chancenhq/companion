require "test_helper"

# The privacy/terms pages are public: members reach them from the onboarding
# consent step before they have a session.
class PagesLegalDocumentsTest < ActionDispatch::IntegrationTest
  test "serves the Kenya privacy policy and terms" do
    get "/privacy/ke"
    assert_response :ok
    assert_select "h1", text: "Kenya Privacy Policy"

    get "/terms/ke"
    assert_response :ok
    assert_select "h1", text: "Kenya Terms of Use"
  end

  test "country code is case insensitive" do
    get "/privacy/KE"

    assert_response :ok
    assert_select "h1", text: "Kenya Privacy Policy"
  end

  test "serves the Rwanda privacy policy" do
    get "/privacy/rw"

    assert_response :ok
    assert_select "h1", text: "PRIVACY POLICY"
    assert_includes response.body, "Law No. 058/2021"
  end

  test "serves the South Africa privacy policy" do
    get "/privacy/za"

    assert_response :ok
    assert_select "h1", text: "South Africa Privacy Policy"
  end

  test "bare privacy and terms default to Kenya" do
    get "/privacy"
    assert_select "h1", text: "Kenya Privacy Policy"

    get "/terms"
    assert_select "h1", text: "Kenya Terms of Use"
  end

  test "serves the Rwanda terms with the Rwanda contact details" do
    get "/terms/rw"

    assert_response :ok
    assert_select "h1", text: "Rwanda Terms of Use"
    assert_includes response.body, "KG 501 St, Kigali, Rwanda"
    assert_not_includes response.body, "Gallagher Avenue"
    assert_includes response.body, "13 June 2026"
    assert_includes response.body, "13 June 2027"
    assert_select "a[href=?]", "mailto:companion@chancen.international"
  end

  test "serves the South Africa terms with the South Africa contact details" do
    get "/terms/za"

    assert_response :ok
    assert_select "h1", text: "South Africa Terms of Use"
    assert_includes response.body, "676 Gallagher Avenue, Halfway House, Midrand"
    assert_not_includes response.body, "KG 501 St"
    assert_includes response.body, "19.05.2026"
    assert_includes response.body, "19.05.2027"
    assert_select "a[href=?]", "tel:+27101584405"
  end

  test "a live country without a published document shows the unavailable notice, never another country's policy" do
    get "/terms/gh"

    assert_response :ok
    assert_select "h1", text: "Terms of Service for Ghana"
    assert_select "a[href=?]", "mailto:#{ChancenCountry.find("GH").escalation_contact}"
    assert_no_match(/Kenya/, response.body)
  end

  test "an unknown country is not found" do
    get "/privacy/xx"
    assert_response :not_found

    get "/terms/xx"
    assert_response :not_found
  end

  test "every live country resolves for both documents" do
    ChancenCountry.live_codes.each do |code|
      %w[privacy terms].each do |document|
        get "/#{document}/#{code.downcase}"

        assert_response :ok, "#{document} for #{code} should render"
      end
    end
  end
end
