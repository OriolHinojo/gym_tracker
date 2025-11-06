# analytics

**Purpose**  
Transforms raw workout data from `LocalStore` into insight snapshots—volume trends, personal records, and time-of-day breakdowns—for the Progress feature.

**Contents & Key Files**
- [analytics_service.dart](analytics_service.dart): Main service computing aggregates, filtering by template/exercise/tag/time, and estimating 1RM.
- [analytics_models.dart](analytics_models.dart): DTOs for filters (`AnalyticsFilters`), trend points, personal records, and time-of-day buckets.

**How It Fits In**
- Entry point(s): `AnalyticsService.snapshot()` → invoked in `ProgressScreen` tabs.
- Upstream deps: `LocalStore`, `Shared SetTag` helpers, Flutter `Material` for `TimeOfDay`.
- Downstream consumers: `lib/screens/progress/progress_screen.dart`, progress widgets (`ProgressLineChart`, `ProgressPointsRecap`), analytics tests.

**State & Architecture**
- Pattern: Stateless service composed on demand; models are immutable value objects.
- Main state owners: None—results returned as new `AnalyticsSnapshot` instances.
- Data flow: Fetch workouts/sets → apply filters → compute session aggregates & PR candidates → return snapshot consumed by UI.

**Public API (surface area)**
- Exposed widgets/classes: `AnalyticsService`, `AnalyticsFilters`, `AnalyticsSnapshot`, `PersonalRecord`, `TimeOfDayVolume`, `TrendPoint`, `TimeOfDayBucket`.
- Navigation: Snapshot session IDs link back to log/session routes (`/sessions/:id`), but service itself is route-agnostic.
- Events/commands: `snapshot()` accepts optional filters; call repeatedly when toggling chips.

**Data & Services**
- Models/DTOs: `AnalyticsSnapshot` (counts, volumes, trends), `TimeOfDayBucket` enums with labels, `PersonalRecord` data.
- Repositories/services: Relies exclusively on `LocalStore`—swap via constructor injection for tests or future data sources.
- External APIs/plugins: None; deterministic calculations (Epley formula).

**Configuration**
- Env/flavors: Pass alternative `LocalStore` via constructor for staging/test data.
- Permissions: Inherits file access needs from `LocalStore`.
- Assets/localization: Labels provided inline (English).

**Testing**
- Coverage focus: `test/analytics_service_test.dart` ensures filter correctness and seeded stats.
- How to run: `flutter test test/analytics_service_test.dart`
- Notable test helpers/mocks: Use `LocalStore.overrideAppDirectory` + `resetForTests` before snapshot calls.

**Gotchas & Conventions**
- `snapshot()` skips sessions without matching sets unless `includeZeroVolumeSessions` is true.
- Time-of-day classification relies on local time converts—ensure stored timestamps stay UTC.
- 1RM estimation uses Epley; adjust `_estimateOneRm` if adopting alternative formulas.
- Sorting utilities (`sortedByOneRm`, `sortTrendPointsByDate`) expect non-null lists—guard before calling.

**Quick Start**
- For dev work here: create a service instance per screen build or provide via DI.
- Example usage:
```dart
final analytics = AnalyticsService();
final snapshot = await analytics.snapshot(
  filters: AnalyticsFilters(tags: {SetTag.amrap}),
);
```
