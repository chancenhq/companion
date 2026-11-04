module AppleSignIn
  Error = Class.new(StandardError)

  JWKS_URI = "https://appleid.apple.com/auth/keys".freeze
  ISSUER   = "https://appleid.apple.com".freeze

  def self.verify!(identity_token)
    jwks_response = Faraday.get(JWKS_URI)
    raise Error, "Failed to fetch Apple public keys" unless jwks_response.success?

    jwks = JWT::JWK::Set.new(JSON.parse(jwks_response.body))
    payload, = JWT.decode(
      identity_token,
      nil,
      true,
      algorithms: %w[RS256],
      jwks: jwks,
      iss: ISSUER,
      verify_iss: true
    )

    client_id = Rails.application.credentials.dig(:apple, :client_id).presence || "international.chancen.companion"
    raise Error, "Invalid audience" unless Array(payload["aud"]).include?(client_id)

    payload
  rescue JWT::DecodeError => e
    raise Error, e.message
  end
end
