# Login reference

This is a short factual reference for the member-facing mobile login behavior verified during the login characterization pass.

## Email/password login

- The Flutter login screen submits email, password, optional MFA code, and mobile device information to `POST /api/v1/auth/login`.
- The backend requires device information and rejects missing required fields or invalid `device_type`.
- On successful email/password login, the backend upserts a `MobileDevice`, revokes active tokens for that same device, and issues OAuth access and refresh tokens that expire after 30 days.
- A wrong password returns `401` with `Invalid email or password` and does not issue tokens.
- Repeated wrong-password attempts do not create tokens or devices. No auth-specific failed-attempt lockout or per-account counter was found.

## Stored auth on app start

- If secure storage contains unexpired OAuth tokens, `AuthProvider` restores them and treats the member as authenticated without a server re-check on app open.
- Actual API requests are still protected by backend token validation.
- If stored OAuth tokens are expired and the app is online, Flutter attempts `/api/v1/auth/refresh`.
- If stored OAuth tokens are expired and the app is offline, Flutter logs out locally and clears stored auth state.
- If secure storage contains `auth_mode: api_key` and an API key, `AuthProvider` restores API-key auth and configures `ApiConfig` without checking whether the build is debug or release.

## SSO and Apple Sign-In

- Google mobile SSO starts through `/auth/mobile/google_oauth2`, then returns to the app with a one-time exchange code.
- `/api/v1/auth/sso_exchange` consumes the one-time code and issues mobile tokens. Missing codes return `400`; invalid, expired, or reused codes return `401`.
- If the provider identity is not linked, the backend creates a temporary linking code and the app shows SSO onboarding.
- SSO onboarding can link an existing local account after email/password authentication, or create a new SSO user when invitation/JIT rules allow it.
- Apple Sign-In verifies the Apple identity token, then issues tokens for an existing Apple identity, links by email when possible, or creates a new SSO user when an email is available.

## Debug API-key login

- The visible API-key login button and backend settings shortcut on `LoginScreen` are wrapped in `kDebugMode`.
- The dialog calls `AuthProvider.loginWithApiKey`, which checks the key by calling `GET /api/v1/accounts` with `X-Api-Key`.
- The backend resolves API keys to their owning user and enforces key expiration, revocation, owner presence/activation, and scopes.

## Session/device behavior

- A new mobile login revokes active tokens for the same `MobileDevice`.
- No global "already logged in elsewhere" session lock was found. A member can have active tokens for different device records at the same time.
