# frozen_string_literal: true

require "test_helper"

class Settings::ChancensControllerTest < ActionDispatch::IntegrationTest
  WHATSAPP_FIELDS = %i[
    whatsapp_group_url_ke
    whatsapp_group_url_rw
    whatsapp_group_url_za
    whatsapp_group_url_gh
  ].freeze

  setup do
    users(:family_admin).update!(role: :super_admin)
    sign_in users(:family_admin)
  end

  teardown do
    WHATSAPP_FIELDS.each { |field| Setting.public_send(:"#{field}=", nil) }
  end

  test "shows country WhatsApp settings to super admins" do
    Setting.whatsapp_group_url_rw = "https://chat.whatsapp.com/rwanda"

    get settings_chancen_url

    assert_response :success
    assert_select "input[name='setting[whatsapp_group_url_ke]']"
    assert_select "input[name='setting[whatsapp_group_url_rw]'][value='https://chat.whatsapp.com/rwanda']"
    assert_select "input[name='setting[whatsapp_group_url_za]']"
    assert_select "input[name='setting[whatsapp_group_url_gh]']"
  end

  test "updates and clears country WhatsApp settings" do
    Setting.whatsapp_group_url_gh = "https://chat.whatsapp.com/old-ghana"

    patch settings_chancen_url, params: { setting: {
      whatsapp_group_url_ke: "https://chat.whatsapp.com/kenya",
      whatsapp_group_url_rw: "https://chat.whatsapp.com/rwanda",
      whatsapp_group_url_za: "https://chat.whatsapp.com/south-africa",
      whatsapp_group_url_gh: ""
    } }

    assert_redirected_to settings_chancen_url
    assert_equal "https://chat.whatsapp.com/kenya", Setting.whatsapp_group_url_ke
    assert_equal "https://chat.whatsapp.com/rwanda", Setting.whatsapp_group_url_rw
    assert_equal "https://chat.whatsapp.com/south-africa", Setting.whatsapp_group_url_za
    assert_nil Setting.whatsapp_group_url_gh
  end

  test "rejects invalid WhatsApp URLs without changing stored links" do
    Setting.whatsapp_group_url_rw = "https://chat.whatsapp.com/original"

    patch settings_chancen_url, params: { setting: {
      whatsapp_group_url_rw: "http://chat.whatsapp.com/not-secure"
    } }

    assert_response :unprocessable_entity
    assert_equal I18n.t("settings.chancens.update.invalid_whatsapp_url"), flash[:alert]
    assert_equal "https://chat.whatsapp.com/original", Setting.whatsapp_group_url_rw
  end

  test "rejects HTTPS URLs outside the WhatsApp group host" do
    patch settings_chancen_url, params: { setting: {
      whatsapp_group_url_za: "https://example.com/not-whatsapp"
    } }

    assert_response :unprocessable_entity
    assert_nil Setting.whatsapp_group_url_za
  end

  test "environment configured links are shown disabled and cannot be overwritten" do
    Setting.whatsapp_group_url_ke = "https://chat.whatsapp.com/stored"

    with_env_overrides("WHATSAPP_GROUP_URL_KE" => "https://chat.whatsapp.com/environment") do
      get settings_chancen_url
      assert_response :success
      assert_select "input[name='setting[whatsapp_group_url_ke]'][value='https://chat.whatsapp.com/environment'][disabled='disabled']"

      patch settings_chancen_url, params: { setting: {
        whatsapp_group_url_ke: "https://chat.whatsapp.com/attempted-overwrite"
      } }
    end

    assert_equal "https://chat.whatsapp.com/stored", Setting.whatsapp_group_url_ke
  end

  test "redirects non-super-admins" do
    users(:family_admin).update!(role: :admin)

    get settings_chancen_url

    assert_redirected_to root_url
    assert_equal I18n.t("settings.chancens.not_authorized"), flash[:alert]
  end
end
