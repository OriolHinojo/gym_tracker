# library

**Purpose**  
Exercise and workout template hub with search/filter, CRUD dialogs, and session previews—serving as the main catalog for logging flows.

**Contents & Key Files**
- [library_screen.dart](library_screen.dart): Tabbed UI containing the exercises list and workout templates manager.

**How It Fits In**
- Entry point(s): GoRouter branch `/library` (`library` route) with nested detail route `/library/exercise/:id`.
- Upstream deps: `LocalStore` for exercise/template CRUD, shared widgets (`showCreateExerciseDialog`, `ProgressFilters`, `SessionPreviewSheet`, chart components), `SetTag` & progress helpers.
- Downstream consumers: Navigates to `LogScreen` via template launch (`context.pushNamed('log', extra: {'templateId': id})`) and exercise detail routes.

**State & Architecture**
- Pattern: Stateful widget with `TabController`; each tab owns local state (query string, refresh token).
- Main state owners: `_LibraryScreenState` tracks search query, tab index, refresh counter; `_ExercisesTabState` and `_WorkoutsTabState` manage Future loads.
- Data flow: User actions trigger `LocalStore` futures (`listExercisesRaw`, `listWorkoutTemplatesRaw`, `createWorkoutTemplate`, `deleteExercise`), and setState refreshes the lists.

**Public API (surface area)**
- Exposed widgets/classes: `LibraryScreen`.
- Navigation: `context.pushNamed('exerciseDetail', pathParameters: {'id': ...})`; templates tab uses `context.pushNamed('log', extra: {'templateId': id})`; preview sheet loads either the latest logged session (when available) or a template summary via `showSessionPreviewSheet`.
- Events/commands: FAB opens `showCreateExerciseDialog` or template dialog; long-press shows edit/delete bottom sheet; template dialog persists selections; preview action button routes to `/log` with `editWorkoutId` when a real session exists.

**Data & Services**
- Models/DTOs: Works with raw `LocalStore` maps; uses `ProgressCalculator` and `ProgressPoint` for charts in previews.
- Repositories/services: Direct `LocalStore` calls; template preview fetches `SessionDetail` via shared loader.
- External APIs/plugins: None beyond Flutter material.

**Configuration**
- Env/flavors: Dialogs depend on seeded data when empty; template creation requires at least one exercise selected.
- Permissions: Inherits `LocalStore` disk requirements.
- Assets/localization: Static English UI copy.

**Testing**
- Coverage focus: No dedicated tests; interactions rely on `LocalStore` template lineage tests.
- How to run: `flutter test` (full suite) after overriding `LocalStore` directory.
- Notable test helpers/mocks: Use `LocalStore.overrideAppDirectory` before launching screen in widget tests.

- **Template previews:** If no logged session matches a template, the preview falls back to synthetic data and omits the edit button; this keeps the shared widget consistent with Home calendar behaviour.
- Exercise long-press bottom sheet exposes destructive delete—ensure confirmation dialog remains in sync with `LocalStore` cleanup.
- Template preview combos volumes/tags via shared widgets; ensure analytics filters align with `ProgressScreen`.
- Refresh tokens increment to reload template list—keep when adding new state.

**Quick Start**
- For dev work here: seed additional exercises via `LocalStore.createExercise` to see search/filter variety.
- Example usage:
```dart
context.pushNamed('log', extra: {'templateId': templateId});
```
