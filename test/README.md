# test

**Purpose**  
Validates IronPulse’s data persistence, analytics aggregation, and key widget behaviours to prevent regressions across refactors.

**Contents & Key Files**
- [widget_test.dart](widget_test.dart): Smoke-test ensuring `IronPulseApp` builds inside a `ProviderScope`.
- [analytics_service_test.dart](analytics_service_test.dart): Verifies `AnalyticsService.snapshot()` volumes, filters (templates, tags, time-of-day).
- [local_store_template_test.dart](local_store_template_test.dart): Confirms `LocalStore.saveWorkout` persists template lineage and tag data.
- [log_screen_focus_test.dart](log_screen_focus_test.dart): Exercises `LogScreen` editor helpers (focus management, duplicate-set behaviour).

**How It Fits In**
- Entry point(s): Run via `flutter test`; CI/regression safety net when altering data store or analytics logic.
- Upstream deps: `flutter_test`, `LocalStore`, `AnalyticsService`, core widgets.
- Downstream consumers: Guides future refactors—tests flag when persistence or analytics contracts change.

**State & Architecture**
- Pattern: Standalone test files using Flutter’s test binding; LocalStore-based suites set up temporary directories.
- Main state owners: Temporary `Directory` per test (`overrideAppDirectory`), `LocalStore.instance` seeded dataset, widget tester harnesses.
- Data flow: Tests reset `LocalStore`, seed workouts, call APIs, and assert on volumes/focus states.

**Public API (surface area)**
- Exposed helpers: `LocalStore.overrideAppDirectory`, `LocalStore.resetForTests`, `LogScreen`’s `debug*` methods provide deterministic hooks for tests.
- Navigation: Widget tests rely on direct `MaterialApp` scaffolds; no full router spin-up.
- Events/commands: Tests invoke `saveWorkout`, `deleteWorkout`, `snapshot`, and widget interactions.

**Data & Services**
- Models/DTOs: Uses raw maps compatible with `LocalStore`; analytics suite inspects `AnalyticsSnapshot`.
- Repositories/services: Exercises `LocalStore` and `AnalyticsService` end-to-end with seeded data.
- External APIs/plugins: None; uses `dart:io` temporary directories.

**Configuration**
- Env/flavors: Tests assume non-web environment (due to `dart:io`); ensure `flutter test` runs on supported platforms.
- Permissions: Temporary directories created in system temp; cleaned up in `tearDown`.
- Assets/localization: Not required—no asset loading.

**Testing**
- Coverage focus: Persistence lineage, analytics calculations, critical Log screen UX invariants, app smoke build.
- How to run: `flutter test`
- Notable test helpers/mocks: Deterministic temp directories, seeded mock data via `LocalStore.init()`.

**Gotchas & Conventions**
- Always call `LocalStore.resetForTests(deleteFile: true)` in `setUp`/`tearDown` to avoid state bleed.
- Widget tests rely on debug helpers—keep them stable when refactoring `LogScreen`.
- Analytics filters expect UTC timestamps; maintain conversions when editing tests.

**Quick Start**
- For dev work here: duplicate existing tests as templates when adding new storage or analytics behaviours.
- Example usage:
```bash
flutter test test/analytics_service_test.dart
```
