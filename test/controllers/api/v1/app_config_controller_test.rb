# frozen_string_literal: true

require "test_helper"

class Api::V1::AppConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    Setting.stubs(:posthog_host).returns(nil)
    Setting.stubs(:posthog_public_key).returns(nil)
    Setting.stubs(:whatsapp_group_url_ke).returns(nil)
    Setting.stubs(:whatsapp_group_url_rw).returns(nil)
    Setting.stubs(:whatsapp_group_url_za).returns(nil)
    Setting.stubs(:whatsapp_group_url_gh).returns(nil)
  end

  test "returns public PostHog configuration without authentication" do
    Setting.stubs(:posthog_host).returns("https://analytics.example.com")
    Setting.stubs(:posthog_public_key).returns("phc_public")

    get api_v1_app_config_path

    assert_response :success
    assert_equal({
      "posthog" => {
        "host" => "https://analytics.example.com",
        "api_key" => "phc_public"
      },
      "whatsapp_group_urls" => {}
    }, response.parsed_body)
  end

  test "omits blank PostHog values" do
    Setting.stubs(:posthog_host).returns("")
    Setting.stubs(:posthog_public_key).returns(nil)

    get api_v1_app_config_path

    assert_response :success
    assert_equal({ "posthog" => {}, "whatsapp_group_urls" => {} }, response.parsed_body)
  end

  test "does not expose private PostHog keys" do
    Setting.stubs(:posthog_host).returns("https://analytics.example.com")
    Setting.stubs(:posthog_public_key).returns("phx_personal")

    get api_v1_app_config_path

    assert_response :success
    assert_equal({
      "posthog" => {
        "host" => "https://analytics.example.com"
      },
      "whatsapp_group_urls" => {}
    }, response.parsed_body)
  end

  test "returns configured country WhatsApp links without authentication" do
    Setting.stubs(:whatsapp_group_url_ke).returns("https://chat.whatsapp.com/kenya")
    Setting.stubs(:whatsapp_group_url_rw).returns("https://chat.whatsapp.com/rwanda")
    Setting.stubs(:whatsapp_group_url_za).returns(nil)
    Setting.stubs(:whatsapp_group_url_gh).returns("")

    get api_v1_app_config_path

    assert_response :success
    assert_equal({
      "posthog" => {},
      "whatsapp_group_urls" => {
        "ke" => "https://chat.whatsapp.com/kenya",
        "rw" => "https://chat.whatsapp.com/rwanda"
      }
    }, response.parsed_body)
  end

  test "returns an empty country map when no links are configured" do
    get api_v1_app_config_path

    assert_response :success
    assert_equal({ "posthog" => {}, "whatsapp_group_urls" => {} }, response.parsed_body)
  end
end
