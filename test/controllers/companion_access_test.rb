require "test_helper"

# Chancen students (User#companion?) only reach the pages in
# CompanionRestrictable::ALLOWLIST. A new page fails this test until someone
# decides whether students should see it.
class CompanionAccessTest < ActionDispatch::IntegrationTest
  # Pages that skip sign-in, so no signed-in user (and no allowlist) applies.
  SKIPS_SIGN_IN = %w[
    registrations archived_exports webhooks
    invitations#accept pages#redis_configuration_error reports#export_transactions
  ].freeze

  setup do
    sign_in @member = users(:family_member)
  end

  test "every page outside the allowlist sends companion users to the assistant" do
    checked = 0

    blocked_get_routes.each do |path, controller, action|
      get path
      assert_redirected_to chats_path, "#{controller}##{action} (GET #{path}) is open to companion users: block it or add it to CompanionRestrictable::ALLOWLIST"
      checked += 1
    end

    assert checked > 40, "expected to check the app's pages, only checked #{checked}"
  end

  test "companion users reach the assistant, their Chancen Account and settings" do
    [ chats_path, my_account_path, payments_my_account_path, settings_profile_path, edit_password_path, settings_appearance_path ].each do |path|
      get path
      assert_response :success, "#{path} should be open to companion users"
    end
  end

  test "home sends companion users to the assistant" do
    get root_path
    assert_redirected_to chats_path
  end

  test "non-HTML requests to blocked pages are refused" do
    get transactions_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :forbidden
  end

  test "navigation matches the mobile app" do
    get chats_path

    assert_select "a[href='#{chats_path}']"
    assert_select "a[href='#{my_account_path}']"
    assert_select "a[href='#{payments_my_account_path}']"
    assert_select "a[href='#{transactions_path}']", count: 0
    assert_select "a[href='#{budgets_path}']", count: 0
    assert_select "a[href='https://discord.gg/36ZGBsxYEK']", count: 0
  end

  test "members who haven't enabled AI are asked to on the assistant page" do
    @member.update!(ai_enabled: false)

    get chats_path

    assert_response :success
    assert_select "input[name='user[ai_enabled]']"
    assert_select "textarea", count: 0
  end

  test "admins keep the full app" do
    sign_in users(:family_admin)

    get transactions_path
    assert_response :success
  end

  private
    def blocked_get_routes
      Rails.application.routes.routes.filter_map do |route|
        next unless route.verb.to_s.split("|").include?("GET")

        controller = route.defaults[:controller].to_s
        action = route.defaults[:action].to_s
        next if controller.blank? || action.blank?
        next unless restricted_controller?(controller)
        next if SKIPS_SIGN_IN.include?(controller) || SKIPS_SIGN_IN.include?("#{controller}##{action}")
        next if ApplicationController.companion_allowed?(controller, action)

        path = route.path.spec.to_s.gsub(/\(.*?\)/, "")
        next if path.include?(":") || path.include?("*")

        [ path, controller, action ]
      end.uniq
    end

    # Controllers that run the companion check (not the API, MCP or engines).
    def restricted_controller?(controller)
      klass = "#{controller.camelize}Controller".safe_constantize
      return false unless klass && klass < ApplicationController

      klass._process_action_callbacks.any? { |callback| callback.filter == :restrict_companion_access }
    end
end
