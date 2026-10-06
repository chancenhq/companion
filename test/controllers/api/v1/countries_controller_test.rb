# frozen_string_literal: true

require "test_helper"

class Api::V1::CountriesControllerTest < ActionDispatch::IntegrationTest
  test "returns live countries from shared Chancen country settings" do
    get api_v1_countries_url

    assert_response :success
    body = JSON.parse(response.body)
    codes = body["countries"].map { |country| country["code"] }

    assert_equal %w[KE RW ZA GH], codes
    assert body["countries"].all? { |country| country["privacy_url"].present? && country["terms_url"].present? }
  end
end
