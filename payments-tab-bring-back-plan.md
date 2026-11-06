# Bring back the Payments tab → `companion-new`

## Context
`companion-new` (the current train) lacks the **Payments** tab that exists on the
`companion` branch. The tab (`IsaTransactionsScreen`, the 3rd student nav destination)
surfaces a student's ISA payment history pulled from the Chancen Metabase warehouse,
completing the student nav: **Assistant → My Account → Payments**. The whole stack —
mobile screen/service/model and the Rails controller/provider — is absent on
`companion-new`; the backend route is present but dangling.

Two product decisions were made:
- **Show ALL payment types** (not just repayment/commitment as companion does today).
- **Base off `companion-new` after the `2c` admin-settings PR merges** — `2c`
  (`merge-new-2c-admin-companion`) adds `Setting.metabase_transactions_question_id`
  and the super-admin Chancen settings page used to configure it, which this work needs.

## Prerequisites / sequencing
1. `2c` must merge into `companion-new` first (provides `metabase_transactions_question_id`
   + the Chancen settings UI).
2. Then branch **`merge-new-2b-payments`** off `companion-new`. PR targets `companion-new`.

## Source of truth
Port files from the `companion` branch: `git show companion/companion:<path>`. Adapt as noted.
All facts below verified against current `companion/companion-new`.

## Backend (Rails)
- **Provider** — add `app/models/provider/metabase_student_transactions.rb`, copy as-is.
  Faraday-based; `TransactionData = Data.define(:payment_type, :amount, :currency, :payment_date)`.
- **Controller** — add `app/controllers/api/v1/my_account_transactions_controller.rb`, copy as-is.
  Relies on `Api::V1::BaseController` (`ensure_read_scope`, `ensure_verified_for_financial_data`,
  `current_resource_owner` — all present on `companion-new`; `ensure_verified_for_financial_data`
  is already applied globally in the base controller, so don't double-declare it), and
  `Setting.metabase_url/metabase_api_key/metabase_transactions_question_id/metabase_email_param`.
- **Route** — already present at `config/routes.rb:874`
  (`resources :my_account_transactions, only: [:index], controller: :my_account_transactions`).
  No change needed.
- **Setting field** — `metabase_transactions_question_id` comes from `2c`. If `2c` is not yet
  merged, this work is blocked (see sequencing); do not re-declare the field here.

## Mobile (Flutter)
- **Model** — add `mobile/lib/models/isa_transaction.dart`, copy as-is (no deps).
- **Exception (REQUIRED adaptation)** — `companion-new` has no `EmailVerificationRequiredException`,
  but both the service and screen import it from `my_account_service.dart`. Add
  `class EmailVerificationRequiredException implements Exception { const EmailVerificationRequiredException(); }`
  to `mobile/lib/services/my_account_service.dart` (alongside the existing
  `AccountNotFoundException` etc. near the top of the file).
- **Service** — add `mobile/lib/services/isa_transactions_service.dart`, copy from companion.
  Imports resolve once the exception is added. Uses `AuthEvents` (present) and its own
  `IsaTransactionsUnavailableException`.
- **Screen** — add `mobile/lib/screens/isa_transactions_screen.dart`, copy from companion, then
  apply the **"show all types"** change:
  - In `_load()`, remove the client-side filter that keeps only `repayment`/`commitment`
    (`result.where((t) => type.contains('repayment') || type.contains('commitment'))`) and use
    all results instead.
  - Change the empty-state copy from `"No repayment transactions found."` to a generic
    `"No transactions found."`.
  - `_TransactionTile`'s `isRepayment` icon/colour styling can stay — it degrades sensibly for
    other types (non-repayment → default styling). Refine per-type presentation later if desired.
  - Keep all states: loading, `VerifyEmailCard` (verify-email), `IsaTransactionsUnavailableException`
    ("not configured yet"), generic error, empty. Deps present: `verify_email_card`,
    `AuthProvider.getValidAccessToken`, `intl`.
- **Nav** — edit `mobile/lib/screens/main_navigation_screen.dart`: add a 3rd `_Tab` to `_tabsFor()`:
  `IsaTransactionsScreen()` with `NavigationDestination(icon: receipt_long_outlined,
  selectedIcon: receipt_long, label: 'Payments')`. **Preserve** `companion-new`'s AI-enable gating
  (`_showEnableAiPrompt` / `aiEnabled` on the Assistant tab) and `_resolveBottomIndex`. **Do NOT**
  add `AnalyticsService` — `companion-new` has none (do not copy companion's nav file wholesale).

## Tests
- Backend: port `test/controllers/api/v1/my_account_transactions_controller_test.rb` from companion;
  adjust expectations for "show all types" (no filtering). Run `bin/rails test`.
- Mobile: add unit tests for the `IsaTransaction` model and `IsaTransactionsService`. Run
  `flutter test` in `mobile/`.

## Conventions
- Mobile screen uses raw Flutter Material (`ListTile`, `Theme.of(context).colorScheme`) matching
  the sibling `insights_screen` — no Rails design-system involvement on the mobile side.
- PR body: follow companion convention — `## Summary`, `## Backend`, `## Mobile`,
  `## Deferred`, `## Verification`, backticked symbols, ending with the Claude Code footer.

## Verification (end-to-end)
- Backend: with `Setting.metabase_url` / `metabase_api_key` / `metabase_transactions_question_id`
  set (via the `2c` Chancen settings page or ENV), `GET /api/v1/my_account_transactions` returns the
  student's rows; returns 503 when unconfigured; `ensure_verified_for_financial_data` blocks
  unverified users.
- Mobile: `flutter analyze` (no new issues) and `flutter test` green. Launch app → Payments tab
  lists **all** payment types, pull-to-refresh works, verify-email card shows for unverified users,
  empty/unavailable states render.
- Regression: Assistant tab still prompts to enable AI when disabled; no analytics breakage.

## Out of scope
- Issue #147 bot taxonomy / `counts_toward_debt` classification (bot-side, separate).
- `get_isa_transactions` assistant function.
- WhatsApp group settings and bulk invite.
