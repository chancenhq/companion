# frozen_string_literal: true

require "test_helper"

class Api::V1::CountriesControllerTest < ActionDispatch::IntegrationTest
  # The country list feeds the pre-sign-up picker and the consent screen's
  # Privacy/Terms links, so it is intentionally public (no API key required).
  test "index returns live countries without authentication" do
    get "/api/v1/countries"

    assert_response :ok
    countries = JSON.parse(response.body).fetch("countries")
    assert_kind_of Array, countries
    assert countries.any?, "expected at least one live country from config"

    countries.each do |country|
      assert_equal true, country["live"], "index must only return live countries"
      assert country["code"].present?
      assert country["name"].present?
      assert country.key?("privacy_url")
      assert country.key?("terms_url")
    end
  end

  test "index matches ChancenCountry.live" do
    get "/api/v1/countries"

    assert_response :ok
    codes = JSON.parse(response.body).fetch("countries").map { |c| c["code"] }
    assert_equal ChancenCountry.live_codes.sort, codes.sort
  end
end
