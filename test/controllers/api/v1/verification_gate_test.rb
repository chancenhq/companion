# frozen_string_literal: true

require "test_helper"

# Issue #106, Story 3.2: every /api/v1 endpoint needs a verified email unless
# it is deliberately allowlisted here. A new controller or action fails this
# test until someone decides which side it belongs on.
class Api::V1::VerificationGateTest < ActionDispatch::IntegrationTest
  # Endpoints unverified users may reach. None of them may expose household or
  # Chancen Account (ISA) data.
  ALLOWLIST = {
    "Api::V1::AuthController" => :all,      # sign-in, sign-up, resend verification
    "Api::V1::ChatsController" => :all,     # the assistant stays available (functions are filtered)
    "Api::V1::MessagesController" => :all,
    "Api::V1::UsageController" => :all,     # API-key metadata only
    "Api::V1::TestController" => :all,      # test-only routes
    "Api::V1::CountriesController" => :all, # country picker, before sign-up
    "Api::V1::UsersController" => %w[me update_country destroy]
  }.freeze

  setup do
    @unverified = users(:unverified)
    @verified = users(:family_admin)
  end

  test "every non-allowlisted API v1 endpoint refuses unverified users" do
    headers = bearer_headers(@unverified)
    checked = 0

    api_v1_routes.each do |route|
      next if allowlisted?(route[:controller_class], route[:action])

      process route[:verb], route[:path], headers: headers, as: :json
      assert_response :forbidden, "#{route[:controller_class]}##{route[:action]} (#{route[:verb].upcase} #{route[:path]}) serves unverified users: gate it or add it to ALLOWLIST"
      assert_equal "email_verification_required", JSON.parse(response.body)["error"]
      checked += 1
    end

    assert checked > 20, "expected to check the financial endpoints, only checked #{checked}"
  end

  test "the lock response tells the app how to recover" do
    get "/api/v1/accounts", headers: bearer_headers(@unverified)

    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal "Verify your email to see your Chancen Account", body["message"]
    assert_equal "resend_email", body["action"]
  end

  test "verified users pass the gate" do
    get "/api/v1/accounts", headers: bearer_headers(@verified)
    assert_response :success
  end

  test "writes are gated too" do
    post "/api/v1/transactions", headers: bearer_headers(@unverified), params: { transaction: { name: "x" } }, as: :json
    assert_response :forbidden
  end

  test "unverified users keep the assistant and their profile" do
    headers = bearer_headers(@unverified)

    get "/api/v1/chats", headers: headers
    assert_not_equal 403, response.status

    get "/api/v1/users/me", headers: headers
    assert_response :success
    assert_equal false, JSON.parse(response.body).dig("user", "email_verified")
  end

  private

    def bearer_headers(user)
      MobileDevice.instance_variable_set(:@shared_oauth_application, nil)
      device = MobileDevice.upsert_device!(user, device_id: "gate-#{user.id}", device_name: "Gate", device_type: "ios", os_version: "17", app_version: "1.0")
      { "Authorization" => "Bearer #{device.issue_token![:access_token]}" }
    end

    def allowlisted?(controller_class, action)
      allowed = ALLOWLIST[controller_class.name]
      allowed == :all || Array(allowed).include?(action)
    end

    def api_v1_routes
      Rails.application.routes.routes.filter_map do |route|
        controller = route.defaults[:controller]
        action = route.defaults[:action]
        next unless controller&.start_with?("api/v1/") && action

        controller_class = "#{controller.camelize}Controller".safe_constantize
        next unless controller_class && controller_class < Api::V1::BaseController

        verb = route.verb.to_s.split("|").first.presence&.downcase
        next unless verb

        path = route.path.spec.to_s.sub("(.:format)", "").gsub(/[:*]\w+/) { SecureRandom.uuid }
        { controller_class: controller_class, action: action, verb: verb.to_sym, path: path }
      end.uniq { |r| [ r[:verb], r[:path].gsub(/\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/, ":id") ] }
    end
end
