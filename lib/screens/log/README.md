# log

**Purpose**  
Workout logging and editing flow with stopwatch, template replay, set management, and deep-link support for existing sessions.

**Contents & Key Files**
- [log_screen.dart](log_screen.dart): Main editor handling templates, stopwatch ticker, set inputs, and persistence.
- [workout_detail_screen.dart](workout_detail_screen.dart): Read-only session detail view with delete/edit actions.

**How It Fits In**
- Entry point(s): GoRouter branch `/log` (`log` route) and deep links `/workout/:id` (extra `workoutId`) or `/log` extras (`templateId`, `editWorkoutId`); detail screen at `/sessions/:id`.
- Upstream deps: `LocalStore` for CRUD, `SessionDetail` loader, shared widgets (`SessionDetailBody`, `SessionPrimaryActionButton`, `SessionPreviewSheet`), `SetTag` helpers, `Ticker` from `flutter/scheduler`.
- Downstream consumers: Navigates back to home/progress via `context.go`; editing route returns to `/log` with populated drafts.

**State & Architecture**
- Pattern: Stateful widget with manual lists of `_ExerciseDraft`/`_SetDraft`, plus a `Ticker`-driven stopwatch.
- Main state owners: `_LogScreenState` holds exercise drafts, expanded panels, editing metadata, template id, and stopwatch status; detail screen caches `Future<SessionDetail>`.
- Data flow: Route extras/template selection → `LocalStore` queries (`getWorkoutTemplateRaw`, `listLatestSetsForExerciseRaw`, `getWorkoutRaw`) → draft builder → user edits sets → `saveWorkout`/`update` operations (not shown but implemented within file) → optional navigation to session detail.

**Public API (surface area)**
- Exposed widgets/classes: `LogScreen`, `WorkoutDetailScreen`.
- Navigation: `context.go('/log', extra: {...})` to open editor with template or existing workout; detail FAB navigates to `/log` for editing; `context.push('/sessions/$id')` to view history without losing back navigation.
- Events/commands: Stopwatch controls (`_ticker.start/pause`), set operations (`_addBlankSet`, `_duplicateLastSet`, `_removeSet`), discard dialog, delete workout confirm in detail view.

**Data & Services**
- Models/DTOs: Works with raw maps from `LocalStore` (workouts, sets), `SessionDetail` for detail view, `SetTag` for tagging sets.
- Repositories/services: Calls `LocalStore` methods (`listRecentWorkoutsRaw`, `saveWorkout`, `listSetsForWorkoutRaw`, `deleteWorkout`).
- External APIs/plugins: None beyond Flutter material/navigation.

**Configuration**
- Env/flavors: Supports template replay via optional extras; relies on seeded data if user has no workouts.
- Permissions: Inherits disk access via `LocalStore`.
- Assets/localization: UI copy inline (English).

**Testing**
- Coverage focus: `test/log_screen_focus_test.dart` validates focus placement and duplicate-set logic; `local_store` tests ensure template metadata persists.
- How to run: `flutter test test/log_screen_focus_test.dart`
- Notable test helpers/mocks: `debugAddExerciseForTest`, `debugWeightHasFocus`, `debugDuplicateLastSetForTest` surfaced for widget tests.

**Gotchas & Conventions**
- Always dispose draft focus nodes (`_ExerciseDraft.dispose`) when clearing state; file handles this in `dispose`.
- Ticker paused when editing an existing workout; resume/reset carefully if extending stopwatch features.
- Template replay prefers template-specific history (`listLatestSetsForExerciseRaw(templateId: ...)`); pass correct ids to show relevant hints.
- Route extras are untyped; perform null/type checks before use.

**Quick Start**
- For dev work here: push extras via `context.go('/log', extra: {'templateId': 1})` to preview template replay.
- Example usage:
```dart
context.go('/log', extra: {'editWorkoutId': workoutId});
```
