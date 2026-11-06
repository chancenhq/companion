# Port `merge-100-analytics` (PostHog) → `companion-new`

## Context
The Companion needs product analytics. `merge-100-analytics` adds a **PostHog**
layer: the Flutter SDK + an `AnalyticsService` singleton, public config delivered
from the backend via `GET /api/v1/app_config`, and event/screen instrumentation
(auth identify, chat events, ISA screen events, per-screen tracking). None of the
mobile analytics exists on `companion-new` (it was deliberately omitted during the
Payments port), and the backend only has partial PostHog support. This plan ports
the net effect onto `companion-new`.

## Scope = 11 commits, 16 files
The analytics work is the contiguous commit range **`1814d486d` … `e8a8d14ab`** on
`companion/merge-100-analytics` (tip `e8a8d14ab`). Everything else on that branch is
unrelated upstream/merge churn — **ignore the full-branch diff**. Source each file
with `git show companion/merge-100-analytics:<path>`.

Net footprint (ignore the generated files — regenerate them):
- Backend: `app/controllers/api/v1/app_config_controller.rb`, `app/models/setting.rb`,
  `config/initializers/posthog.rb`, `.env.example`
- Mobile: `mobile/pubspec.yaml`, `mobile/lib/services/analytics_service.dart`,
  `mobile/lib/providers/app_config_provider.dart`, `mobile/lib/main.dart`,
  `mobile/lib/providers/auth_provider.dart`, `mobile/lib/providers/chat_provider.dart`,
  `mobile/lib/providers/my_account_provider.dart`, `mobile/lib/screens/main_navigation_screen.dart`
- Generated (DO NOT hand-port — produced by `flutter pub get`): `mobile/pubspec.lock`,
  `mobile/android/.../GeneratedPluginRegistrant.java`, `mobile/ios/Runner/GeneratedPluginRegistrant.m`,
  `mobile/android/settings.gradle`

## Approach: hand re-apply, NOT cherry-pick
`merge-100-analytics`'s merge-base with `companion-new` is ancient, so cherry-picking
conflicts massively. Re-apply the net effect file-by-file against **current**
`companion-new` files.

## companion-new baseline (verified)
- `config/initializers/posthog.rb` **already present and richer** than the analytics
  branch's (sets `api_key`/`host` from `POSTHOG_KEY`, plus feedback surveys). 
- **No** `Setting.posthog_public_key` / `Setting.posthog_host` fields.
- `GET /api/v1/app_config` **route exists** (`config/routes.rb:876`,
  `resource :app_config, only: [:show], controller: :app_config`) **but the controller
  is ABSENT** — dangling route, must be created.
- Mobile: no `posthog_flutter`, no `analytics_service.dart`, no `app_config_provider.dart`;
  `main_navigation_screen.dart` has the Payments tab (from `2b`) and no analytics.

## Prerequisites / sequencing
- Land **after `2b` (Payments)** is merged into `companion-new`. Branch
  `merge-new-100-analytics` (or similar) off `companion-new` then. Reason:
  `main_navigation_screen.dart` is touched by both, and per-screen tracking must
  include the new **Payments** tab's screen name.
- PR targets `companion-new`.

## Backend
1. **`Setting`** — add two fields (from the branch):
   ```ruby
   field :posthog_public_key, type: :string, default: ENV["POSTHOG_KEY"].presence || ENV["POSTHOG_PUBLIC_KEY"].presence
   field :posthog_host, type: :string, default: ENV.fetch("POSTHOG_HOST", "https://us.i.posthog.com")
   ```
   (Public, write-only client token — safe to deliver to the app.)
2. **Create `app/controllers/api/v1/app_config_controller.rb`** behind the existing
   route. Base it on companion's version but **return only what companion-new supports**:
   ```ruby
   # show payload
   { posthog: { host: Setting.posthog_host.presence, api_key: Setting.posthog_public_key.presence }.compact }
   ```
   **Drop companion's `whatsapp` block** — those settings aren't on companion-new. Mirror
   companion's auth posture for this endpoint (it's a client bootstrap config endpoint —
   check `Api::V1::AppConfigController` on `companion` for its `skip_before_action` /
   public-access setup and replicate it).
3. **`config/initializers/posthog.rb`** — companion-new's version already sets
   `api_key`/`host`; the only analytics-branch change is a `POSTHOG_PUBLIC_KEY` fallback
   alias. Optional; apply only the one-line fallback if desired, otherwise no-op.
4. **`.env.example`** — add the cosmetic `POSTHOG_PUBLIC_KEY` deprecated-alias comment.

## Mobile (re-apply against current companion-new files)
5. **`pubspec.yaml`** — add `posthog_flutter: ^4.0.0`, then run `flutter pub get` in
   `mobile/` (this regenerates `pubspec.lock`, both `GeneratedPluginRegistrant.*`, and
   `settings.gradle` — commit those as generated output, don't hand-edit).
6. Add verbatim: `mobile/lib/services/analytics_service.dart` (PostHog singleton
   wrapper) and `mobile/lib/providers/app_config_provider.dart` (fetches
   `/api/v1/app_config`, holds PostHog config). Confirm the provider's fetch path
   matches companion-new's route.
7. **`main.dart`** — initialise PostHog from the app_config response and register the
   `PosthogObserver` in `MaterialApp.navigatorObservers`. Re-apply into companion-new's
   current `main.dart` (don't overwrite — it has diverged).
8. **`auth_provider.dart`** — wire `AnalyticsService` identify + auth events. Re-apply by
   hand (file has diverged).
9. **`chat_provider.dart`** — capture `new_chat_started` + `chat_message_sent`.
10. **`my_account_provider.dart`** — capture `isa_screen_viewed` + `isa_load_failed`.
    Confirm companion-new's insights `my_account_provider` and wire there.
11. **`main_navigation_screen.dart`** — add per-screen tracking
    (`AnalyticsService.instance.screen(...)` / the `_tabScreenNames` list). Re-apply on
    top of the Payments-tab version and **include the Payments tab's screen name** (the
    companion tracked list used `isa_transactions`). This is the analytics↔payments
    intersection point.

## Risks to reconcile (verify against current companion-new)
- `app_config` controller created from scratch with correct public-access posture.
- Mobile `main.dart` / providers / nav have diverged → hand re-apply, never raw patch.
- Confirm `PosthogObserver` registration point and the `app_config_provider` fetch path.
- If Payments (`2b`) isn't merged yet, resolve the `main_navigation_screen.dart` overlap.

## Verification
- Backend: add an app_config controller test (returns PostHog config when set; keys
  absent/empty when unset). `ruby -c` on changed files. Full Rails suite in CI.
- Mobile: `flutter analyze` clean on changed files; `flutter test` green. Manual: app
  boots → PostHog initialises from `app_config`; screen/nav events fire on tab switches
  (incl. Payments); `identify` fires on login; chat + ISA events emit.

## Out of scope
- WhatsApp settings (not on companion-new; omit the whatsapp block from app_config).
- Any new analytics events beyond those in the 11 commits.
