# frozen_string_literal: true

require "test_helper"

class Api::V1::AppConfigControllerTest < ActionDispatch::IntegrationTest
  test "returns configured country WhatsApp links without authentication" do
    Setting.stubs(:whatsapp_group_url_ke).returns("https://chat.whatsapp.com/kenya")
    Setting.stubs(:whatsapp_group_url_rw).returns("https://chat.whatsapp.com/rwanda")
    Setting.stubs(:whatsapp_group_url_za).returns(nil)
    Setting.stubs(:whatsapp_group_url_gh).returns("")

    get api_v1_app_config_path

    assert_response :success
    assert_equal({
      "whatsapp_group_urls" => {
        "ke" => "https://chat.whatsapp.com/kenya",
        "rw" => "https://chat.whatsapp.com/rwanda"
      }
    }, response.parsed_body)
  end

  test "returns an empty country map when no links are configured" do
    Setting.stubs(:whatsapp_group_url_ke).returns(nil)
    Setting.stubs(:whatsapp_group_url_rw).returns(nil)
    Setting.stubs(:whatsapp_group_url_za).returns(nil)
    Setting.stubs(:whatsapp_group_url_gh).returns(nil)

    get api_v1_app_config_path

    assert_response :success
    assert_equal({ "whatsapp_group_urls" => {} }, response.parsed_body)
  end
end
