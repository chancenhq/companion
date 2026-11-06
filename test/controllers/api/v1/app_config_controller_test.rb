# frozen_string_literal: true

require "test_helper"

class Api::V1::AppConfigControllerTest < ActionDispatch::IntegrationTest
  test "returns public PostHog configuration without authentication" do
    Setting.stubs(:posthog_host).returns("https://analytics.example.com")
    Setting.stubs(:posthog_public_key).returns("phc_public")

    get api_v1_app_config_path

    assert_response :success
    assert_equal({
      "posthog" => {
        "host" => "https://analytics.example.com",
        "api_key" => "phc_public"
      }
    }, response.parsed_body)
  end

  test "omits blank PostHog values" do
    Setting.stubs(:posthog_host).returns("")
    Setting.stubs(:posthog_public_key).returns(nil)

    get api_v1_app_config_path

    assert_response :success
    assert_equal({ "posthog" => {} }, response.parsed_body)
  end

  test "does not expose private PostHog keys" do
    Setting.stubs(:posthog_host).returns("https://analytics.example.com")
    Setting.stubs(:posthog_public_key).returns("phx_personal")

    get api_v1_app_config_path

    assert_response :success
    assert_equal({
      "posthog" => {
        "host" => "https://analytics.example.com"
      }
    }, response.parsed_body)
  end
end
