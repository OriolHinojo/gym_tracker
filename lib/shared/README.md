# shared

**Purpose**  
Cross-feature domain helpers and lightweight view models that keep screens/widgets consistent (session detail loading, progress math, tagging, icons).

**Contents & Key Files**
- [session_detail.dart](session_detail.dart): Loads a workout into `SessionDetail`/`SessionExercise`/`SessionSet` models using `LocalStore`.
- [progress_calculator.dart](progress_calculator.dart): Normalises raw set rows into chart-ready aggregates (avg per session, ordinal picks).
- [progress_types.dart](progress_types.dart): Shared enums/DTOs for progress aggregation modes and ranges.
- [set_tags.dart](set_tags.dart): Tag enum with storage helpers, icons, labels, and parse utilities.
- [formatting.dart](formatting.dart): Central helpers for ISO date parsing, duration clocks, and common two-digit padding.
- [exercise_category_icons.dart](exercise_category_icons.dart): Category-to-`IconData` resolver for consistent visuals.

**How It Fits In**
- Entry point(s): `loadSessionDetail` (session previews), `ProgressCalculator.buildSeries` (analytics charts).
- Upstream deps: `LocalStore` for session hydration; Flutter `Material` for icons and `IconData`.
- Downstream consumers: Home session preview, Library/Progress screens, `SessionPreviewSheet`, analytics widgets, `AnalyticsService`.

**State & Architecture**
- Pattern: Pure functions and immutable data classes; no global state.
- Main state owners: None—callers retain returned view models.
- Data flow: `LocalStore` JSON → `SessionDetail` models → UI; raw set rows → `ProgressCalculator` → `ProgressPoint` list for charts and recaps.

**Public API (surface area)**
- Exposed widgets/classes: `SessionDetail`, `SessionExercise`, `SessionSet`, `ProgressCalculator`, `ProgressPoint`, `SetTag`, `ProgressAggMode`, `ProgressRange`.
- Navigation: `SessionDetail` IDs align with `/sessions/:id`; other helpers route-agnostic.
- Events/commands: Helper functions like `setTagFromStorage`, `setTagLabelFromStorage`.

**Data & Services**
- Models/DTOs: Session models, progress aggregation types, `SetTag` metadata.
- Repositories/services: `loadSessionDetail` directly queries `LocalStore`; `ProgressCalculator` consumes raw rows from `LocalStore` or analytics snapshots.
- External APIs/plugins: None beyond Flutter core.

**Configuration**
- Env/flavors: Not configurable; rely on caller-provided data.
- Permissions: No direct IO.
- Assets/localization: No ARB integration—labels are inline English strings.

**Testing**
- Coverage focus: Exercised indirectly via `library`/`progress` widget tests and analytics unit tests.
- How to run: `flutter test test/analytics_service_test.dart` (verifies tag helpers & progress models indirectly).
- Notable test helpers/mocks: Use `LocalStore.overrideAppDirectory` before calling `loadSessionDetail` in tests.

**Gotchas & Conventions**
- `loadSessionDetail` throws `StateError` if workout missing—wrap in try/catch when loading user-provided IDs.
- `ProgressCalculator` expects timestamps in UTC strings; ensure `created_at` values exist when adding migrations.
- `setTagFromStorage` returns `null` for unknown strings—handle gracefully when parsing historic data.
- Keep helper enums synced with UI chips (progress filters rely on both label + short values).

**Quick Start**
- For dev work here: inject `ProgressCalculator` into analytics features instead of duplicating aggregation logic.
- Example usage:
```dart
final detail = await loadSessionDetail(1);
final points = const ProgressCalculator().buildSeries(
  await LocalStore.instance.listSetsForExerciseRaw(1),
  mode: ProgressAggMode.avgPerSession,
  range: ProgressRange.w8,
);
```
