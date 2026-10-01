# Issue 106 Testing: Country Routing, Email Sign-in, Email Verification

GitHub issue: https://github.com/chancenhq/companion/issues/106

## Epic 1: Country routing

### Story 1.1: Pick my country

Server-side build:
- Added `config/chancen_countries.yml` with Kenya, Rwanda, South Africa, and Ghana.
- Added `GET /api/v1/countries` so the client can render the picker from the shared country settings.

Mobile build:
- Added `mobile/lib/models/chancen_country.dart` and `mobile/lib/services/countries_service.dart`.
- Replaced the old onboarding country step with `CountrySelectionScreen`.
- Removed the `ipapi.co` lookup and removed Kenya as the silent default.
- The picker starts with no country selected and requires legal consent before continuing.

Tests:
- `test/controllers/api/v1/countries_controller_test.rb`
  - Confirms the API returns `KE`, `RW`, `ZA`, and `GH`.
  - Confirms each returned country includes privacy and terms URLs.
- `mobile/test/models/chancen_country_test.dart`
  - Confirms country API payload parsing.
  - Confirms relative privacy/terms URLs resolve against the configured backend.

Result:
- Passed in focused test run.

### Story 1.2: Save my country on the server

Server-side build:
- Added `users.country_code` with supported-code validation.
- Added database check constraint for `KE`, `RW`, `ZA`, and `GH`.
- Added `PATCH /api/v1/users/me/country` for saving country after sign-up/sign-in.
- Added `country_code` to mobile signup payloads and auth user responses.

Mobile build:
- Added `AuthProvider.updateCountry` and `AuthService.updateCountry`.
- Persisted the chosen country name/code locally after the server accepts it.
- Added user model fields for `country_code`, `email_verified`, and `requires_country_confirmation`.

Tests:
- `test/controllers/api/v1/auth_controller_test.rb`
  - Saves lowercase `rw` as `RW` during signup.
  - Rejects unsupported `US`.
- `test/controllers/api/v1/users_controller_test.rb`
  - Saves lowercase `ke` as `KE`.
  - Rejects unsupported `US`.
- `mobile/test/models/user_test.dart`
  - Confirms the app parses and serializes country and verification fields.

Result:
- Passed in focused test run.

### Story 1.3: The bot answers for my country

Server-side build:
- Assistant instructions now read the member's `country_code`.
- Removed the hardcoded Kenya escalation instruction.
- Missing country uses neutral "the Chancen team" wording.
- Ghana uses general ISA content until country-specific content is ready.
- Rwanda users get `isa_content_source: rwanda`; assistant instructions tell the bot to include both `rwanda` and `Rwanda` when searching family files for ISA answers.

Tests:
- `test/models/assistant/configurable_test.rb`
  - Rwanda users get Rwanda team/contact instructions.
  - Rwanda users get Rwanda ISA source/search instructions.
  - Users without country get neutral guidance and no Kenya default.

Result:
- Passed in focused test run.

### Story 1.4: Country settings in one place

Server-side build:
- `ChancenCountry` loads from `config/chancen_countries.yml`.
- Country list API, user validation, and assistant routing all read through `ChancenCountry`.

Tests:
- Covered by country API, auth/user validation, and assistant config tests above.

Result:
- Passed in focused test run.

### Story 1.5: Existing members confirm their country

Server-side build:
- Existing users are not assigned a country.
- Existing users are backfilled as email-verified only when they have a Google or Apple identity.
- Email/password users stay unverified and verify once through email confirmation.
- Mobile auth payloads include `requires_country_confirmation`.
- Server never defaults missing country to Kenya.

Mobile build:
- `AppWrapper` routes authenticated users with missing country to `CountrySelectionScreen`.
- The app can require country confirmation after login even when first-run onboarding is already complete.

Tests:
- `test/controllers/api/v1/auth_controller_test.rb`
  - Signup/login payloads expose `country_code` and `requires_country_confirmation`.
- `test/models/assistant/configurable_test.rb`
  - Missing country stays neutral and does not default to Kenya.

Result:
- Passed in focused test run.

## Epic 2: Clear email sign-in

### Story 2.1: See how to sign in with email

Server-side build:
- Existing mobile auth responses now include the country and verification state the app needs after email sign-in.

Mobile build:
- Login/onboarding now show Google, Apple on iOS, and `Continue with email` as equal-weight sign-in choices.
- Email helper copy tells students to use the email address they gave Chancen.
- Email sign-up shows password rules before typing and returns plain validation messages.
- Forgot password remains on the email sign-in form.

Tests:
- `test/controllers/api/v1/auth_controller_test.rb`
  - Login response includes `country_code`, `email_verified`, and `requires_country_confirmation`.

Result:
- Passed in focused test run.

## Epic 3: Email verification

### Story 3.1: Verify my email when I create an account

Server-side build:
- Added `users.email_verified_at`.
- Existing Google/Apple users are backfilled as verified in the migration.
- Existing email/password users remain unverified.
- New email signups send a verification email using the existing 24-hour email confirmation token pattern.
- Email confirmation now marks initial signup emails verified.
- SSO/Apple-created or linked accounts are marked verified automatically.
- Added `POST /api/v1/auth/resend_email_verification`.

Mobile build:
- Added `EmailVerificationScreen` after email signup/login when the user is unverified.
- Added resend verification support through `AuthProvider.resendEmailVerification`.
- Added "Use a different email" logout path.

Tests:
- `test/controllers/api/v1/auth_controller_test.rb`
  - New signup returns `email_verified: false`.
- `test/controllers/email_confirmations_controller_test.rb`
  - Existing email-change confirmation still redirects successfully.
  - Initial signup confirmation marks `email_verified_at`.
- `test/mailers/email_confirmation_mailer_test.rb`
  - Email-change confirmation sends to `unconfirmed_email`.
  - Initial verification sends to the current email.

Result:
- Passed in focused test run.

### Story 3.2: Use the bot while I wait

Server-side build:
- Chat/bot endpoints remain available for unverified users.
- Financial data endpoints for accounts, balance sheet, and transactions return no data when email is unverified.
- Lock response message: "Verify your email to see your Chancen Account".

Mobile build:
- The verification screen lets unverified users continue into the assistant.
- Accounts, balance sheet, and transaction sync now surface the backend verification lock message instead of a generic failure.
- Locally cached account/transaction data is cleared when the server reports `email_verification_required`.

Tests:
- `test/controllers/api/v1/accounts_controller_test.rb`
  - Unverified user is blocked from account data.
- `test/controllers/api/v1/balance_sheet_controller_test.rb`
  - Unverified user is blocked from balance sheet data.
- `test/controllers/api/v1/transactions_controller_test.rb`
  - Unverified user is blocked from transaction data.

Result:
- Passed in focused test run.

## Test Run

Focused Rails command:

```sh
bin/rails test test/controllers/api/v1/countries_controller_test.rb test/controllers/api/v1/auth_controller_test.rb test/controllers/api/v1/users_controller_test.rb test/controllers/api/v1/accounts_controller_test.rb test/controllers/api/v1/balance_sheet_controller_test.rb test/controllers/api/v1/transactions_controller_test.rb test/controllers/email_confirmations_controller_test.rb test/mailers/email_confirmation_mailer_test.rb test/models/assistant/configurable_test.rb
```

Result:

```text
146 runs, 705 assertions, 0 failures, 0 errors, 0 skips
```

Full Rails command:

```sh
bin/rails test
```

Result:

```text
4307 runs, 17823 assertions, 0 failures, 0 errors, 26 skips
```

Mobile command:

```sh
cd mobile && flutter test
```

Result:

```text
/bin/bash: line 1: flutter: command not found
```

The Flutter unit tests were added in `mobile/test/models/user_test.dart` and `mobile/test/models/chancen_country_test.dart`, but this workspace cannot execute them locally because the Flutter SDK is not installed.
