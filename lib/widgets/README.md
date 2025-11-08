# widgets

**Purpose**  
Reusable UI building blocks—dialogs, charts, recap cards, and session components shared across feature screens.

- **Contents & Key Files**
  - [create_exercise_dialog.dart](create_exercise_dialog.dart): Modal creation/edit dialog shared by Library tab; wraps `LocalStore` CRUD.
  - [session_preview_sheet.dart](session_preview_sheet.dart): Bottom sheet renderer for session previews, composed of header + exercises list plus optional primary action.
  - [session_detail_body.dart](session_detail_body.dart): Shared scrollable body (header + exercise list) for sheets and full detail screens.
  - [session_primary_action_button.dart](session_primary_action_button.dart): Floating action button variant reused by previews/detail screens.
  - [session_header.dart](session_header.dart): Gradient card summarising session metadata (name, date, exercise/set counts).
  - [session_exercises.dart](session_exercises.dart): Expandable list/cards for exercise sets with optional tags.
  - [progress_filters.dart](progress_filters.dart): Chip-based aggregation/range selector reused by analytics views.
  - [progress_line_chart.dart](progress_line_chart.dart): CustomPainter sparkline for progress trends.
  - [progress_points_recap.dart](progress_points_recap.dart): List card showing raw `ProgressPoint` values.
  - [workout_editor.dart](workout_editor.dart): Shared workout editor (stopwatch, template replay, persistence callbacks) reused by log screen and inline edit flows.

**How It Fits In**
- Entry point(s): Imported by screens (`library`, `log`, `progress`, `home`) to compose feature UIs.
- Upstream deps: Flutter `Material`, `LocalStore`, shared models (`SessionDetail`, `ProgressPoint`, `SetTag`).
- Downstream consumers: Home overview, session detail sheet, Library workouts tab, Progress analytics.

**State & Architecture**
- Pattern: Mostly stateless widgets; a few stateful controllers for animations (`AnimatedSize`, expansion toggles).
- Main state owners: `SessionExerciseCard` toggles expansion; `SessionPreviewSheet` defers to `FutureBuilder`.
- Data flow: Callers supply futures/models; widgets render them without internal persistence (delegating to `LocalStore` callers).

- **Public API (surface area)**
  - Exposed widgets/classes: `WorkoutEditor`, `WorkoutEditorResult`, `showWorkoutEditorPage`, `SessionPreviewSheet`, `SessionPreviewAction`, `SessionDetailBody`, `SessionPrimaryActionButton`, `SessionHeaderCard`, `SessionExercisesList`, `SessionExerciseCard`, `ProgressLineChart`, `ProgressFilters`, `ProgressPointsRecap`, `showCreateExerciseDialog`.
  - Navigation: Sheet utilities may call `Navigator.pop`; preview sheet triggered from Library/Home to deep link toward `/sessions/:id` or launch `showWorkoutEditorPage` for inline edits.
  - Events/commands: Dialog returns `CreatedExercise`; preview sheets optionally surface `SessionPreviewAction` callbacks; workout editor emits `WorkoutEditorResult` on save; cards expose expansion toggles; filters emit callbacks on chip selection.

**Data & Services**
- Models/DTOs: Accepts `SessionDetail`, `ProgressPoint`, progress enums, `Future<SessionDetail>`.
- Repositories/services: Indirectly touches `LocalStore` via dialog helper and session futures.
- External APIs/plugins: None; custom painter uses core Flutter canvas.

**Configuration**
- Env/flavors: No special config; ensure `Theme.of(context).extension<BrandColors>()` available for cards if styling reused.
- Permissions: Dialog writes via `LocalStore`; observe storage constraints.
- Assets/localization: Static English strings; adapt when localisation is added.

**Testing**
- Coverage focus: Currently no direct widget tests—behaviour validated via feature tests (e.g., `log_screen_focus_test.dart`).
- How to run: `flutter test` (feature tests exercise these components indirectly).
- Notable test helpers/mocks: `showCreateExerciseDialog` uses `LocalStore` test overrides automatically.

- **Session preview**: `SessionPreviewSheet` expects a `Future<SessionDetail>`; handle errors upstream or rely on built-in error text. Provide `SessionPreviewAction` only when the detail represents a real session (id > 0) to show the shared edit button.
- `ProgressLineChart` assumes non-empty point lists for axis scaling; guard at caller when data absent.
- Dialog returns `null` on cancel—check before using the result.
- Displayed weights follow the persisted units preference (kg/lb) exposed via `LocalStore.weightUnitListenable`.

**Quick Start**
- For dev work here: import target widget into a story/sandbox screen and feed mock data.
- Example usage:
```dart
await showSessionPreviewSheet(
  context,
  sessionFuture: loadSessionDetail(1),
  title: 'Last session',
  primaryAction: SessionPreviewAction(
    label: 'Edit',
    onPressed: (sheetCtx, detail) {
      Navigator.of(sheetCtx).pop();
      showWorkoutEditorPage(
        context,
        editWorkoutId: detail.id,
      );
    },
  ),
);
```
