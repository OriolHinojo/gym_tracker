# screens

**Purpose**  
Feature-facing UI for IronPulse, covering dashboard, logging, analytics, library management, and settings surfaces wired into the app router.

**Contents & Key Files**
- [home/home_screen.dart](home/home_screen.dart): Landing overview; listens to `LocalStore` stats, recent sessions, and preferred exercise notifier.
- [log/log_screen.dart](log/log_screen.dart): Workout logger/editor with stopwatch, template replay, and set tagging; paired with [log/workout_detail_screen.dart](log/workout_detail_screen.dart).
- [library/library_screen.dart](library/library_screen.dart): Exercise/template library with tabbed search, creation dialogs, and preview sheets.
- [progress/progress_screen.dart](progress/progress_screen.dart): Analytics dashboard using `AnalyticsService` plus progress widgets.
- [more/more_screen.dart](more/more_screen.dart): Settings stub featuring the global `ThemeSwitcher`.

**How It Fits In**
- Entry point(s): `GoRouter` branches (`router.dart`) push `/`, `/log`, `/progress`, `/library`, `/more`, `/sessions/:id`.
- Upstream deps: `LocalStore`, widgets in `lib/widgets`, shared helpers (`progress_calculator`, `session_detail`), `AnalyticsService`.
- Downstream consumers: Routed via `MaterialApp.router`; tests target `LogScreen` focus behaviour and session detail interactions.

**State & Architecture**
- Pattern: Stateful widgets with controllers (`Ticker`, `TabController`) alongside async builders; no global state aside from Riverpod theme provider.
- Main state owners: `_LogScreenState` manages logger drafts; `_LibraryScreenState` holds tab/query state; `_TemplatesTabState` keeps filter sets.
- Data flow: UI triggers `LocalStore` futures → `FutureBuilder`/`ValueListenableBuilder` render lists; analytics tab requests snapshots → charts/widgets.

**Public API (surface area)**
- Exposed widgets/classes: `HomeScreen`, `LogScreen`, `WorkoutDetailScreen`, `LibraryScreen`, `ProgressScreen`, `MoreScreen`.
- Navigation: Named GoRouter routes (`home`, `log`, `progress`, `library`, `exerciseDetail`, `sessionDetail`, `more`, `workout`); pass extras `{templateId, editWorkoutId}` to reuse `LogScreen`.
- Events/commands: Logging actions (`_loadWorkoutFromId`, `_applyTemplate`, `_duplicateLastSet`) commit via `LocalStore`; Library dialogs call `showCreateExerciseDialog`.

**Data & Services**
- Models/DTOs: Uses `SessionDetail` for previews, `ProgressPoint` for charts, `SetTag` enums for tagging.
- Repositories/services: `LocalStore` (workouts/exercises/templates), `AnalyticsService` (progress insights).
- External APIs/plugins: Relies on standard Flutter material, `go_router`.

**Configuration**
- Env/flavors: None; route extras determine context (template vs edit mode).
- Permissions: Follows `LocalStore` storage constraints; UI warns when data missing.
- Assets/localization: No dedicated assets—icons from Material.

**Testing**
- Coverage focus: `test/log_screen_focus_test.dart` (focus management), `test/widget_test.dart` (bootstrap sanity).
- How to run: `flutter test test/log_screen_focus_test.dart`
- Notable test helpers/mocks: `_LogScreenState.debug*` helpers surfaced for widget tests.

**Gotchas & Conventions**
- `LogScreen` owns a running `Ticker`; ensure `dispose` is maintained when extending the editor.
- Route extras come through `GoRouterState.extra` untyped—defensively cast before use.
- Library template dialog expects at least one exercise selected; guard creation UX when adding validation.
- Analytics tabs rely on seeded data; empty stores should handle gracefully (cards display placeholders).

**Quick Start**
- For dev work here: run `flutter run` and use the bottom navigation to explore each screen; deep-link via `flutter run --route=/sessions/1`.
- Example usage:
```dart
context.goNamed('log', extra: {'templateId': 1});
```
