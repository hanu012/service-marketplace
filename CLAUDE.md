# Project: Service Marketplace Platform

## What this is
A service marketplace connecting vendors (AC repair, plumbing, electrical,
etc.) to customers, sold primarily through a salesman-led channel, with
vendor self-signup as a secondary path. Admin manages master data and
approvals.

## Stack
- Backend: Laravel 12, PHP 8.3, MySQL/MariaDB (spatial columns for zones —
  local dev runs on XAMPP's MariaDB 10.4)
- Admin: Filament v3, dark mode on, primary color set in the panel
  provider — no separate frontend app
- Mobile: Flutter 3.x, GetX — but specifically the pattern in
  `mobile/lib/screens/**`, not generic GetX. See "Flutter conventions"
  below before writing any screen.
- Auth: Laravel Sanctum, one personal access token per device
- File storage: Laravel Filesystem, S3 driver → Cloudflare R2
- Queue: Laravel Queue (database driver is fine at this scale) +
  Laravel Scheduler for the daily expiry job
- Push: Firebase Cloud Messaging via HTTP v1 API
- Email: Laravel Mail + Resend

## Architecture — Laravel backend
No restriction here on repositories, interfaces, or DTOs — use standard
Laravel patterns wherever they genuinely help. The "keep it flat, no
abstractions" rule further down applies to the **Flutter app only**, not
this backend.

- Controllers can call Eloquent models directly for simple CRUD, or go
  through a repository/service if that's clearer for the feature —
  your call.
- Multi-table transactional logic (e.g. `SubscriptionService::subscribe()`,
  `ZoneMatcher::vendorsFor($lat, $lng, $subcategoryId)`) belongs in
  `app/Services` regardless of whether repositories are used elsewhere.
- Validation lives in Form Requests, not inline in controllers.
- Reusable query logic can live in Eloquent scopes/accessors
  (`Vendor::active()`, `Subscription::expiringWithin(30)`) for simple
  cases, or a repository for more complex data access — either is fine.
- Prefer a well-named Artisan command over a custom Laravel Event +
  Listener class pair (with EventServiceProvider registration) for a
  one-off, single-consumer action — that's unnecessary ceremony for
  something that's really just a direct method call or a scheduled job.
  This does NOT apply to Eloquent model lifecycle events
  (`saving`/`saved`/`deleting`) used for cross-cutting concerns like
  audit logging (task 2.2) or the deletion guards (SPEC §10) — that's
  standard, idiomatic Laravel and stays.

## Conventions — API (Laravel)
- API response envelope: { success, data, error: { code, message } }
- Pagination via Laravel's built-in paginator on every list endpoint,
  EXCEPT bounded master-data endpoints consumed to populate app selection
  UI (categories, zones, plans) — these return the full result unpaginated
  since apps need the whole set in one request to render a browse grid or
  quota-selection screen. Endpoints backed by unbounded/growing
  collections (leads, reviews, users, vendors) still paginate normally.
- Money stored as integer paise, never float
- Dates in UTC, ISO 8601
- Server always recalculates price, quota usage, and expiry dates —
  never trusts client-sent values
- Subscription-creating endpoints require an `Idempotency-Key` header,
  enforced with a unique column
- Soft deletes (`SoftDeletes` trait) on: users, vendors, subscriptions
- Password reset tokens expire in 15 minutes, single use
- Email verification links expire in 24 hours
- Widening an existing enum column (adding a new status value) needs a
  raw `DB::statement("ALTER TABLE ... MODIFY ... ENUM(...)")` migration
  — Laravel's `->change()` isn't reliably supported on enum columns via
  Doctrine DBAL. This will recur any time a lifecycle gets a new state
  (e.g. vendors.status gaining 'rejected' in task 4.3).

## Filament testing conventions
Two gotchas that will recur on every resource with a reorder or inline
toggle column — write tests the correct way from the start rather than
rediscovering these:
- Drag-to-reorder is NOT a chainable Livewire test helper — call the
  reorder method directly with `->call(...)`.
- `ToggleColumn` is not an action — testing it via
  `callTableColumnAction` silently no-ops and the test passes regardless
  of whether the toggle works. Use `updateTableColumnState` and read the
  resulting value back from the database directly, never trust the
  response alone.
- For "this action must not exist" requirements (e.g. no delete on
  master data per SPEC §10), assert the action is absent from the
  resource, not that it's present-but-disabled — this fails loudly if a
  later edit re-adds it, rather than silently reintroducing a live path.
- Before naming a method on a class that extends a framework base class
  (Filament components, Laravel's `TestCase`, anything similar), check
  the base class doesn't already declare it with a different signature.
  Confirmed twice now: `getDefaultView()` collided with Filament's
  `ViewComponent`, and `withToken()` collided with Laravel's own
  `TestCase` (already public there, redeclaring it private was the
  break). A collision is a fatal error, not a warning, and takes down
  the whole test run — check the base class first, in any framework.
- No third-party CDN scripts in the admin panel, ever — vendor JS
  dependencies locally via npm + `filament:assets` instead. The panel
  edits payments, subscriptions, and vendor verification; a compromised
  or MITM'd CDN script would run with full admin session privileges.
  This applies to future chart/rich-text/widget libraries too, not just
  Leaflet.
- A field with `dehydrated(false)` is also excluded from
  `mutateFormDataBefore*` hooks, not just from the saved model — if a
  hook needs to read that field to convert it (e.g. rupees entered,
  paise stored), keep the field dehydrated and `unset()` it inside the
  hook instead, or the hook receives nothing and the conversion silently
  no-ops (every value saves as the default/zero).
- A `Fieldset` using `->relationship('quota')` implicitly calls
  `statePath('quota')` — nested field state lives at `quota.max_zones`,
  not a flat `max_zones`. A test calling `fillForm()` with flat keys
  silently leaves the defaults in place rather than erroring, so the
  resulting test failure looks like an arbitrary wrong number instead of
  an obviously unfilled field. Nest test data to match the relationship
  path.
- For any field whose editability depends on the current user's role
  (not just the admin-permissions field), use `->hidden()`, never
  `->disabled()`. A disabled field's state still round-trips through the
  request — Filament doesn't stop a crafted submission from setting it
  regardless of what the rendered form shows. Hidden means it was never
  part of the form's state to begin with.
- Eloquent auto-calls `boot{TraitName}()` for traits (and `booted()` on
  the model) — this is a naming *convention*, not a hook you register.
  A plausible-looking `bootSomething()` that doesn't exactly match the
  trait's name is simply never called, with no error — the opposite
  failure mode from the collision above (that one crashes loudly; this
  one does nothing silently, e.g. a tracked column staying null
  forever). Get the trait name exactly right.

## Flutter conventions — follow the existing demo-app pattern exactly
Every screen is a `<name>_module/` folder with exactly two files. Do not
introduce bindings classes, repositories, use-cases, or `.obs`/reactive
streams — this app does not use them anywhere and new screens must match
the old ones, not "improve" on the pattern.

- **Controller** (`<name>_controller.dart`): extends `GetxController`.
  Plain (non-reactive) fields — booleans, strings, lists — mutated
  directly, followed by a call to `update()`. Forms use a
  `GlobalKey<FormState> formKey`. One method per screen action (e.g.
  `addUserNameAPI()`), calling `DataSource.instance.xxxAPI(body: body)`,
  wrapped in try/catch, toggling `Utils.showCircularProgressLottie()`
  around the call. Parse the response with `Model.fromJson()`, persist via
  `Injector.setUserData(...)` when relevant, navigate with
  `Utils.transitionWithOffAll(NextScreen())`.
- **View** (`<name>_view.dart`): a `StatelessWidget`. `build()` returns
  `GetBuilder<XController>(init: XController(), dispose: (_) =>
  Get.delete<XController>(), builder: (controller) => Scaffold(...))`.
  Read/write controller state off the builder argument as
  `controller.fieldName`. **Do not name the builder parameter `_`** —
  Dart 3.7+ treats `_` as a non-binding wildcard, so `_.field` is a hard
  compile error on this SDK, even though it worked in the original
  demo-app on an older Dart version. Use the `<name>_view.dart` /
  `<name>_controller.dart` shared `Base*` widgets (`BaseTextField`,
  `BaseRaisedButton`, `BaseTextDMSans`, ...) instead of raw Material
  widgets wherever one exists.
- **API layer**: add one named method per endpoint to
  `network/data_source.dart` (`DataSource.instance.xxxAPI(...)`). Do not
  create per-feature API classes or a generic HTTP repository.
- **Response shape**: every API method returns a `CommonResponse`
  (status/data/message from `common_model/`); parse `.data` into a typed
  model with a `fromJson` factory.
- **Shared state**: anything that needs to persist or be read across
  screens (access token, user profile, prefs) goes through the static
  `Injector` class, not a new state-management layer.
- **Strings**: add to `StringRes`, wrap with `easy_localization`'s `.tr()`.
- **Colors**: from `ColorRes` only — no inline hex values in a screen.
- **Spacing/sizing**: use the existing `.getSize` / `.heightSpacer`
  extensions for anything that should scale with screen size.
- **Imports**: start every new screen file with
  `import '../../../constants/app.export.dart';` (adjust relative depth)
  rather than importing individual constant/util files piecemeal, matching
  the existing files.

## Theme
Dark by default, user-switchable (not forced). Verified values from the
Filament panel — use the same direction in Flutter:
- Primary accent: teal-400 `#2dd4bf`
- Surface: slate-900 `#0f172a`
- Page background: slate-950 `#020617` — deliberately not pure black
Teal specifically avoids colliding with Filament's reserved red/amber for
destructive/warning states — don't "simplify" to amber later, it breaks
status legibility. No custom Tailwind build for the admin — Filament's
panel-provider color config is sufficient, no npm build step needed.

## Roles
admin | salesman | vendor | customer — enforced with Laravel Policies +
Sanctum token abilities. No custom guard system.

## Domain entities
See SPEC.md for full field list: users, vendors, salesmen, customers,
categories, subcategories, zones, plans, plan_quotas, subscriptions,
subscription_items, payments, commissions, leads, reviews, media,
banners, notifications, audit_logs, settings, cms_pages.

## Local environment
XAMPP provides MariaDB 10.4 (used by the app) and Apache/phpMyAdmin (NOT
used to run the app — Apache is unused; `php artisan serve` runs the API
instead). The `php`/`composer`/`artisan` CLI on this machine resolves to
a **separate winget-installed PHP 8.3**, not XAMPP's bundled PHP — two
distinct PHP runtimes exist here. The `intl` extension must be enabled in
BOTH php.ini files (winget's, which is what actually runs the app, and
XAMPP's, kept in sync to avoid surprises if Apache/phpMyAdmin is ever
used) — Laravel's `Number::currency()`/`Number::format()` helpers require
it, and this app formats money constantly given SPEC stores everything
as integer paise. Confirm `intl` is enabled on the production server too
in Phase 8 — that will be a single, normal PHP install with no such split.

Ad-hoc verification zones created via tinker/live-check (not through the
seeder) should use coordinates outside the seeded Ahmedabad range — e.g.
`-33.0, -70.0` — rather than `ZoneFactory`'s default square, which lands
inside real seeded coordinate space and can collide with a genuine
seeded zone (happened in tasks 4.6 and 5.3: a point intended for the
ad-hoc zone matched a real seeded zone instead, since both geometrically
contained it). Not a bug — `ZoneMatcher` picked the correct leaf zone
for the point it was given — just a live-check hygiene rule not worth
re-deriving each time.

Live-check cleanup must force-delete, not soft-delete. A soft-deleted
row still occupies unique indexes (email, phone), so a leftover row
from a prior session's live-check can silently break a later session's
reseed with a duplicate-entry error (happened in task 5.4: task 5.3's
cleanup used `User::where(...)->delete()`, which soft-deletes since
`User` uses `SoftDeletes`, and the trashed row's email blocked task
5.4's reseed). Use `withTrashed()->forceDelete()` for every model in a
live-check cleanup script, not `delete()`.

## Current phase
Phase 0 — foundation setup

## Do not
- Do not add a payment gateway SDK yet. Keep a single `PaymentService`
  with `payViaCash()` / `payOnline()` / `recordFreeTrial()` methods —
  real gateway wiring later changes the internals, not the callers.
- Do not use OTP/phone auth — email + password only.
- **(Flutter only)** Do not introduce repository interfaces, DTO layers,
  bindings classes, or "for future flexibility" abstractions in the
  mobile app — match the existing demo-app pattern exactly. This does
  NOT apply to the Laravel backend, which is free to use repositories,
  services, or DTOs where useful.
