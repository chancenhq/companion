require "test_helper"

class AppleSignInTest < ActiveSupport::TestCase
  DUMMY_PAYLOAD = { "sub" => "user123", "aud" => "international.chancen.companion" }.freeze

  def stub_jwt(payload: DUMMY_PAYLOAD, client_id: nil)
    Rails.application.credentials.stubs(:dig).with(:apple, :client_id).returns(client_id)
    jwks_response = stub(success?: true, body: { keys: [] }.to_json)
    Faraday.stubs(:get).with(AppleSignIn::JWKS_URI).returns(jwks_response)
    JWT.stubs(:decode).returns([ payload ])
  end

  test "falls back to default bundle ID when credential is absent (nil)" do
    stub_jwt(client_id: nil)
    result = AppleSignIn.verify!("token")
    assert_equal DUMMY_PAYLOAD, result
  end

  test "falls back to default bundle ID when credential is blank string" do
    stub_jwt(client_id: "")
    result = AppleSignIn.verify!("token")
    assert_equal DUMMY_PAYLOAD, result
  end

  test "falls back to default bundle ID when credential is whitespace-only" do
    stub_jwt(client_id: "   ")
    result = AppleSignIn.verify!("token")
    assert_equal DUMMY_PAYLOAD, result
  end

  test "uses custom client_id when credential is present" do
    custom_id = "com.custom.app"
    stub_jwt(payload: { "sub" => "user123", "aud" => custom_id }, client_id: custom_id)
    result = AppleSignIn.verify!("token")
    assert_equal custom_id, result["aud"]
  end

  test "raises Error when audience does not match" do
    stub_jwt(payload: { "sub" => "user123", "aud" => "wrong.bundle.id" }, client_id: nil)
    assert_raises(AppleSignIn::Error) { AppleSignIn.verify!("token") }
  end
end
