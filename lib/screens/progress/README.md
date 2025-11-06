# progress

**Purpose**  
Analytics dashboard visualising workout volume, personal records, and trend insights across templates and exercises.

**Contents & Key Files**
- [progress_screen.dart](progress_screen.dart): Hosts tabbed analytics UI (`Templates` and `Exercises`) backed by `AnalyticsService` and shared widgets.

**How It Fits In**
- Entry point(s): GoRouter branch `/progress` (`progress` route) within bottom navigation shell.
- Upstream deps: `AnalyticsService` for snapshots, `LocalStore` (via service) for raw data, shared helpers (`ProgressCalculator`, `ProgressFilters`, `SetTag`), analytics models.
- Downstream consumers: Links back to session previews, library filters, and may trigger navigation to templates/log via future enhancements.

**State & Architecture**
- Pattern: Stateful tabs inside a `DefaultTabController`; each tab manages filters and async loads.
- Main state owners: `_TemplatesTabState` maintains selected template, tag/time filters, cached Future; `_ExercisesTabState` keeps selected exercise, aggregation mode, range, and analytics future.
- Data flow: Filters → `_load()` fetches snapshot (templates) or raw sets + calculator (exercises) → UI renders cards, charts, tables using shared widgets.

**Public API (surface area)**
- Exposed widgets/classes: `ProgressScreen`.
- Navigation: None directly; list tiles emphasize analytics context (future extension point).
- Events/commands: Filter chips modify `_tagFilters`, `_timeFilters`, `ProgressAggMode`, `ProgressRange`; reload triggers new snapshot.

**Data & Services**
- Models/DTOs: `AnalyticsSnapshot`, `PersonalRecord`, `TimeOfDayVolume`, `TrendPoint`, `ProgressPoint`.
- Repositories/services: Calls `AnalyticsService.snapshot()`; exercises tab reuses `ProgressCalculator.buildSeries`.
- External APIs/plugins: None beyond Flutter material.

**Configuration**
- Env/flavors: Works with seeded demo data; filters default to “all templates/exercises”.
- Permissions: Inherits `LocalStore` disk access.
- Assets/localization: Text inline (English).

**Testing**
- Coverage focus: `test/analytics_service_test.dart` validates backend logic; screen itself untested.
- How to run: `flutter test test/analytics_service_test.dart`
- Notable test helpers/mocks: Replace `AnalyticsService` with mocks for widget tests if needed.

**Gotchas & Conventions**
- Templates tab uses `_allTemplates` sentinel (-1) for “All templates”; maintain when adding options.
- When filters exclude all sessions, UI should display empty states—ensure new widgets handle `AnalyticsSnapshot.empty`.
- Exercise tab expects `ProgressCalculator` to receive non-empty lists; guard before rendering charts.

**Quick Start**
- For dev work here: tweak analytics filters or add new buckets in `AnalyticsModels` then expose chips in `_openFiltersBottomSheet`.
- Example usage:
```dart
setState(() => _mode = ProgressAggMode.set1);
_future = _load();
```
