# services

**Purpose**  
Encapsulates derived analytics, contracts, and mocks that sit above raw storage—turning workout data into insights and reusable service interfaces.

**Contents & Key Files**
- [analytics/analytics_service.dart](analytics/analytics_service.dart): Aggregates volumes, PRs, and time-of-day stats from `LocalStore`.
- [analytics/analytics_models.dart](analytics/analytics_models.dart): Filter/query DTOs (`AnalyticsFilters`, `TimeOfDayVolume`, `TrendPoint`, etc.).
- [contracts/services.dart](contracts/services.dart): Interfaces for metrics and suggestion engines plus lightweight `Point` DTO.
- [mocks/mock_services.dart](mocks/mock_services.dart): Deterministic mock implementations for previews/tests.

**How It Fits In**
- Entry point(s): `AnalyticsService.snapshot()` → invoked by `ProgressScreen` tabs.
- Upstream deps: `LocalStore`, shared `SetTag` helpers, Flutter `Material` for `TimeOfDay`.
- Downstream consumers: Progress feature, analytics widget tests, potential future DI layers replacing mocks.

**State & Architecture**
- Pattern: Stateless service objects; analytics caches nothing between calls.
- Main state owners: `AnalyticsService` holds a `LocalStore` reference; mocks generate pseudo-random data per invocation.
- Data flow: Raw rows (`LocalStore.listWorkoutsRaw`/`listAllSetsRaw`) → filter pipeline → aggregates (volume trend, PR candidates) → UI view models.

**Public API (surface area)**
- Exposed widgets/classes: `AnalyticsService`, `AnalyticsSnapshot`, `AnalyticsFilters`, `MockMetricsService`, `MockSuggestionEngine`.
- Navigation: None, but templates/exercise IDs align with GoRouter routes (`/library`, `/progress`, `/sessions/:id`).
- Events/commands: `snapshot()` synchronous compute triggered by screens; mocks expose `suggestNext`, `estimateE1RM`.

**Data & Services**
- Models/DTOs: `AnalyticsSnapshot` summarises volumes; `PersonalRecord` tracks best estimated 1RM; `TimeOfDayBucket` anchors breakdowns.
- Repositories/services: Works atop `LocalStore`; contracts in `services.dart` define future replacements (e.g., remote metrics engines).
- External APIs/plugins: No third-party API calls—pure computation over local data.

**Configuration**
- Env/flavors: None required; pass a custom `LocalStore` instance for testing with `AnalyticsService(store: ...)`.
- Permissions: Inherits file access needs via `LocalStore`; no additional setup.
- Assets/localization: Not applicable.

**Testing**
- Coverage focus: `test/analytics_service_test.dart` verifies filters (template, tag, time-of-day) and seeded volume totals.
- How to run: `flutter test test/analytics_service_test.dart`
- Notable test helpers/mocks: `LocalStore.overrideAppDirectory`, `MockMetricsService` for constant data series.

**Gotchas & Conventions**
- `snapshot()` skips zero-volume sessions unless `includeZeroVolumeSessions` is set—match UI expectations when adding filters.
- Time-of-day classification uses local time (`TimeOfDayBucketX.classify`); ensure stored timestamps remain UTC.
- Personal record detection uses Epley estimate; adjust in `AnalyticsService._estimateOneRm` if adopting other formulas.
- Mock services seed `Random(42)` for repeatable charts—changing the seed alters demo visuals.

**Quick Start**
- For dev work here: instantiate `final analytics = AnalyticsService();` once per screen build.
- Example usage:
```dart
final snapshot = await AnalyticsService().snapshot(
  filters: AnalyticsFilters(tags: {SetTag.dropSet}),
);
```
