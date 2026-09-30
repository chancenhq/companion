# Security backlog

Running list of security, privacy, and general hardening opportunities noticed during test characterization. These entries are separate from the test-scenario tracker and PR descriptions so the team can review them on its own schedule.

For each new finding, include both likelihood questions separately:

- External exploitation likelihood: How likely exploitation is by someone outside the team, given the actual access path required to reach the issue at all.
- Internal ordinary-use likelihood: How likely it is that this has already happened through ordinary, non-malicious internal use, such as a developer or tester using a real account/key instead of a dummy one and never undoing it.

If either answer is unknown, say so plainly and name the specific fact that would resolve it.

## Raw mobile user payloads are logged in release builds

- What I found: The Flutter auth service logs raw user payloads after login, signup, SSO exchange, SSO account linking, SSO account creation, Apple Sign-In, and enable-AI responses. The logging path is not guarded by `kDebugMode`, and the Settings screen exposes the in-app debug log viewer without a release-build guard.
- Why it matters: Mobile user payloads can include account identifiers and profile fields. In release builds, those payloads can be retained in the app's in-memory log list and copied from the debug log viewer, which creates avoidable privacy exposure.
- Where in the code: `mobile/lib/services/auth_service.dart` (`_logRawUserPayload` and callers), `mobile/lib/services/log_service.dart` (`LogService#log` records all levels before calling `debugPrint`), and `mobile/lib/screens/settings_screen.dart` (unguarded "Debug Logs" navigation).

## Multiple device sessions stay active for the same member

- What I found: Issuing a mobile OAuth token revokes active tokens for the same `MobileDevice`, but it does not revoke tokens for other mobile devices belonging to the same user.
- Why it matters: A member can remain logged in on multiple different device records at the same time. That may be intended, but it means "already logged in elsewhere" is not enforced as a global account/session state and should be an explicit product/security decision.
- Where in the code: `app/models/mobile_device.rb` (`active_tokens`, `revoke_all_tokens!`, and `issue_token!`) and the token-issuing paths in `app/controllers/api/v1/auth_controller.rb`.

## No auth-specific lockout for repeated password or MFA failures

- What I found: The mobile login endpoint returns `401` for wrong passwords and MFA failures, but I found no per-account failed-attempt counter, lockout, or auth-specific throttle for repeated failures. Rack::Attack provides broad production/staging `/api/` IP throttles, but not a login-specific control.
- Why it matters: Broad IP throttles help reduce abuse, but they do not protect a specific member account from distributed or low-rate credential attacks. Repeated failure behavior should be covered by an explicit product/security decision.
- Where in the code: `app/controllers/api/v1/auth_controller.rb` (`login`), `config/initializers/rack_attack.rb` (broad API throttles only), and `app/models/user.rb`/schema fields around OTP and authentication state.

## SSO onboarding can persist linking state before mobile token issuance

- What I found: `sso_link` creates the `OidcIdentity` before calling `issue_mobile_tokens`, and `sso_create_account` creates the user plus `OidcIdentity` before token issuance. If mobile device registration fails after those writes, the request returns an error but linking/account state may already be persisted.
- Why it matters: A failed mobile sign-in/onboarding attempt can leave partial account-binding state behind. This makes retries and auditability harder, and can create confusing or sensitive account-link side effects from a flow the mobile client sees as failed.
- Where in the code: `app/controllers/api/v1/auth_controller.rb` (`sso_link`, `sso_create_account`, `jit_create_sso_user`, and `issue_mobile_tokens`) and `app/controllers/sessions_controller.rb` (`mobile_sso_start`/`handle_mobile_sso_onboarding` cache device info after presence checks).

## Persisted API-key auth is restored without a release-build guard

- What I found: The visible API-key login dialog is wrapped in `kDebugMode`, but `AuthProvider` restores `auth_mode == "api_key"` from secure storage on startup in any build mode. When an API key is present, the app marks the session authenticated and configures `ApiConfig` for `X-Api-Key` requests without checking whether the current build is debug or release.
- Why it matters: A production/release app install can continue using API-key auth if the key was already saved. The key is not a fixed test account credential; the debug dialog accepts any active API key, and the backend resolves it to the owning user with that key's `read` or `read_write` scopes. A restored `read` key can read that user's accessible family/account data through API endpoints, and a restored `read_write` key can also use write endpoints such as transaction/chat/sync actions where the API allows them. From the code path I found, the realistic way this happens is a real device first runs a debug/internal build with the same app identity, signs in through the debug API-key dialog, and is later upgraded to a release build without clearing app data/keychain/secure storage. This is not reachable from the normal release login UI, but persisted state bypasses that UI restriction.
- Where in the code: `mobile/lib/screens/login_screen.dart` (`kDebugMode` wraps the API-key button/dialog entry point), `mobile/lib/providers/auth_provider.dart` (`_loadStoredAuth` restores API-key mode), `mobile/lib/services/auth_service.dart` (`_saveApiKey`, `getStoredApiKey`, `getStoredAuthMode`), and `mobile/lib/services/api_config.dart` (`setApiKeyAuth`/`getAuthHeaders`).
- External exploitation likelihood: Low based on the code path found so far. An outside attacker would need either an active API key already saved on the device, or the ability to get a debug/internal build with the same app identity onto a real device and enter a valid key. I did not find a normal production UI path to create or enter the API key.
- Internal ordinary-use likelihood: Unknown, but plausibly higher than external exploitation. The realistic path is a developer/tester using a real API key on a real device in a debug/internal build, then later upgrading to a release build without clearing app storage. The fact that would resolve this is whether internal/test devices have ever used the debug API-key dialog against real accounts or production-like API keys, and whether those devices were later upgraded in place.

## Expired stored tokens force logout when the app starts offline

- What I found: When stored OAuth tokens are expired at app startup, the mobile app checks connectivity. If it is offline, it immediately calls `logout()` and clears local auth state instead of keeping a temporary offline/grace state.
- Why it matters: This is not necessarily a security bug, but it is a product decision worth making explicitly. Members in Kenya, Rwanda, and South Africa may lose signal while away from stable connectivity; if their token expires during that period, reopening the app signs them out immediately and may block access until they can authenticate again.
- Where in the code: `mobile/lib/providers/auth_provider.dart` (`_loadStoredAuth` connectivity check and offline `logout()` branch), `mobile/lib/services/auth_service.dart` (`logout` deletes stored tokens/user/auth mode), and `mobile/lib/models/auth_tokens.dart` (`isExpired` calculation).
- External exploitation likelihood: Not applicable as an exploitation path based on the code read so far. This is a product/reliability tradeoff, not a security bypass or data exposure.
- Internal ordinary-use likelihood: Unknown. It is plausible for real members to encounter this naturally if they reopen the app after token expiry while offline, especially in intermittent-connectivity contexts. The fact that would resolve this is production telemetry or support reports showing how often app startup happens with expired stored tokens and no connectivity, and whether that leads to sign-in/support friction.
