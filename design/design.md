# 💪 IronPulse — Implementation Overview (Flutter • Dart • Offline)

> Snapshot of the features that currently ship in the codebase. Use this as the reference for how the app really behaves today.

---

## 1) 🎯 Product Snapshot

- Offline-first workout tracker that persists everything to a JSON file (`LocalStore`) via `path_provider`.
- Platforms: Android/iOS/macOS/Windows/Linux (no Web because file I/O is required).
- Focus: quick workout logging, lightweight progress charts, simple template management.
- Single-user prototype — all data is stored locally for user id `1`.

---

## 2) 🧱 Architecture & Routing

- `main.dart` injects a `ProviderScope` and boots `IronPulseApp` (`lib/app.dart`).
- Navigation driven by `GoRouter` with a `StatefulShellRoute` bottom navigation scaffold (`lib/router.dart`):
  - `/` → **Home**
  - `/log` → **Log**
  - `/progress` → **Progress**
  - `/library` → **Library**
  - `/library/exercise/:id` → exercise analytics detail
  - `/more` → **More**
  - `/workout/:id` → deep link that opens **Log** with an existing workout (read-only preload).
- Theme mode (system / light / dark) controlled globally via Riverpod (`theme/mode_provider.dart`).

---

## 3) 💾 Persistence Layer (`lib/data/local/local_store.dart`)

- Simple JSON “database” written to `~/Documents/.../gym_tracker_db.json`.
- Auto-initialises on first access; seeds demo data:
  - 3 exercises, 3 workouts, 6 sets, 1 workout template.
  - Empty `prs` and `body_metrics` tables for forward compatibility.
- Atomic writes: temp file + rename protects against corruption.
- Public APIs used in UI:
  - `listExercisesRaw()`, `getExerciseRaw(id)` — sorted metadata for list & detail screens.
  - `createExercise(...)` — invoked from the shared dialog.
  - `listWorkoutTemplatesRaw() / getWorkoutTemplateRaw(id)` and `create/deleteWorkoutTemplate(...)`.
  - `listRecentWorkoutsRaw(limit)`, `listSetsForWorkoutRaw(workoutId)` — drive “repeat workout”.
  - `listSetsForExerciseRaw(exerciseId)` and `listLatestSetsForExerciseRaw(exerciseId)` — history + placeholder data.
  - `saveWorkout(...)` — persists finished sessions and appends individual sets.
  - `getHomeStats()` — computes weekly session count, e1RM delta for the favourite exercise, and last-session exercises. Uses the internal `_seedMockData()` and e1RM (Epley) formula.
- Emits `preferredExerciseIdListenable` (`ValueNotifier<int?>`) so the Home dashboard reacts to favourites.
- Not available on Web (`assert(!kIsWeb)`); all screens rely on this guard.

---

## 4) 📚 Domain & Service Layer Stubs

- `lib/models/` holds rich domain models (Exercise, Workout, SetEntry, etc.) and enums. They are not yet wired into the UI but define the longer-term shape.
- `lib/services/contracts/` and `lib/services/mocks/` describe planned analytics services (e1RM trend, suggestions). Current UI does not consume them; Progress analytics rely on the local calculator instead.
- Keep these stubs when expanding the data layer (e.g. swapping `LocalStore` with Drift or SQLite).

---

## 5) 🏠 Home (`lib/screens/home/home_screen.dart`)

- App bar gradient accent pulled from `BrandColors`.
- Summary grid (`_SummaryGrid`) displays:
  - Sessions logged this week (count from `LocalStore.getHomeStats()`).
  - e1RM delta vs. previous week for the favourite exercise (auto-selected or user-set).
  - Exercises performed in the most recent session.
- Content updates through `ValueListenableBuilder` hooked to `preferredExerciseIdListenable`.
- Recent sessions list now ships an inline “eye” icon that opens the shared session preview bottom sheet. The sheet uses the centralised `SessionDetail` loader and renders the new primary-container header card with workout metadata chips; exercise cards stay collapsed by default for a quick skim and expand to larger weight/rep typography on demand.
- “Highlights” card is currently static placeholder copy.
- FAB: `Quick Start` → opens `/log`.

---

## 6) 📝 Log (`lib/screens/log/log_screen.dart`)

### Entry points
- Choose between starting fresh, repeating a previous workout, or jumping to Library templates.
- Optional deep links:
  - `templateId` (GoRouter `extra`) loads saved workout templates as editable drafts.
  - `/workout/:id` loads past workout sets as read-only placeholders (checkboxes default unchecked).

### Workout editor
- Custom ticker/stopwatch (`Ticker` class) keeps elapsed session time (pause/resume supported).
- Per exercise block:
  - Displays name + category.
  - History button opens the detailed analytics screen (`ExerciseDetailScreen`).
  - Edit toggle expands to show set table with:
    - Weight + reps text fields (prefilled from latest history when available).
    - Completion checkbox (visual only; save respects numeric inputs).
    - Delete set button.
  - “Add set” uses history hints to prefill values.
- “Add exercise” bottom sheet:
  - Searchable list of all exercises from `LocalStore`.
  - “Create new exercise” uses the shared dialog and automatically inserts the new entry.
- The dedicated workout detail screen now reuses the shared session header + exercise list widgets, ensuring the collapsible set cards behave the same way as in previews (tap to expand sets, weight/reps hidden by default).

### Actions
- **Save as template**: collects current exercise ids and persists a workout template via `LocalStore.createWorkoutTemplate`.
- **Finish**: validates numeric sets, writes them with `saveWorkout`, then resets screen state and restarts the timer.
- Snackbars confirm success/failure for all major flows.

---

## 7) 📦 Library (`lib/screens/library/library_screen.dart`)

- Tabbed interface (`TabController`) with **Exercises** and **Workouts (templates)**.

### Exercises tab
- Text field filters exercises client-side.
- Tapping a row pushes `/library/exercise/:id` showing analytics for that exercise.
- Floating action button opens `showCreateExerciseDialog` (same dialog as Log screen).

### Workouts tab
- Lists persisted templates; supports preview, delete, and “Run in Log”.
- “New Workout Template” dialog allows picking exercises via checkboxes and persists to `LocalStore`.
- Template preview bottom sheet now goes through the shared session preview UI. It fabricates a lightweight `SessionDetail` (id `0`) that pulls the most recent recorded sets per exercise, so users see real weights/reps alongside a note clarifying the data source.

### Exercise detail (`ExerciseDetailScreen`)
- Loads exercise info, raw sets, and preferred exercise status.
- Users can set/clear favourite (`LocalStore.setPreferredExerciseId`) to influence the Home dashboard.
- Shares the analytics widgets with the Progress screen (filters, chart, recap).

---

## 8) 📈 Progress Analytics

- Shared types in `lib/shared/progress_types.dart` define aggregation modes (average per session, set 1/2/3) and time windows (4–12 weeks, all time).
- `ProgressCalculator.buildSeries(...)` transforms raw set rows into `ProgressPoint` data:
  - Filters invalid entries, groups by workout, averages or selects set ordinal.
  - Applies date window filtering.
- `ProgressScreen` (`lib/screens/progress/progress_screen.dart`) lets users:
  - Pick an exercise (dropdown).
  - Toggle aggregation mode + range via `ProgressFilters`.
  - View custom line chart (`ProgressLineChart`) and exact point list (`ProgressPointsRecap`).
- Exercise detail screen reuses the same calculator and UI components, keeping analytics consistent.

---

## 9) 🧩 Shared Widgets & Utilities

- `SessionDetail` (`lib/shared/session_detail.dart`): single source of truth for loading workouts, grouping sets per exercise, and resolving exercise names.
- `SessionPreviewSheet`, `SessionHeaderCard`, `SessionExercisesList`: reusable session UI primitives. The header card sits on the brand `primaryContainer`, adds template/session chips (exercise count, total sets), and surfaces notes inline. Exercise cards start collapsed, show summary stats (set count, total reps, top set), and expand on tap to reveal set lists with enlarged weight/rep text for readability.
- `ProgressFilters`: wrap of choice chips with optional `leading` widgets for extra controls.
- `ProgressLineChart`: lightweight `CustomPainter` line chart (no external chart dependency used despite `fl_chart` being listed).
- `ProgressPointsRecap`: simple card listing all generated `ProgressPoint`s.
- `create_exercise_dialog.dart`: reusable flow for adding exercises with predefined categories and optional custom label.
- `Ticker` (within `log_screen.dart`): minimal stopwatch helper around `Stopwatch`.

---

## 10) 🎨 Theming & Settings

- `buildLightTheme` / `buildDarkTheme` (`lib/theme/theme.dart`) apply a Material 3 seed theme with brand gradient extension (`BrandColors`).
- Components customised: NavigationBar, AppBar, cards, chips, input fields, dialog/bottom sheet shapes.
- `ThemeSwitcher` (displayed on the **More** screen app bar) cycles theme mode using Riverpod state.
- **More** screen (`lib/screens/more/more_screen.dart`):
  - Theme toggle is functional.
  - Unit, e1RM formula, export/import, and privacy lock switches are placeholders (UI stubs only).

---

## 11) 🧪 Testing & Tooling

- Lints: `very_good_analysis` + Flutter lints (configured in `analysis_options.yaml`).
- Tests: single smoke test (`test/widget_test.dart`) verifying that `IronPulseApp` builds; no integration or unit coverage yet.
- Dependencies declared in `pubspec.yaml`; unused packages (`fl_chart`, `freezed`, etc.) are ready for future work but not referenced in current code.

---

## 12) 🚧 Known Gaps & Next Steps

- Logging UX lacks advanced set types (drop sets, RPE/RIR input, timers per exercise) described in earlier concepts.
- Progress analytics operate on basic averages; no e1RM curve, rep filtering, or template comparisons yet.
- Import/export, PR tracking, and body metrics tables are seeded but unused.
- No persistence of workout metadata beyond name (always saved as “Workout”) or session duration.
- Test coverage is minimal; consider adding unit tests for `LocalStore` and `ProgressCalculator`.

Use this document when extending the app so new features stay in sync with the implementation.

---

*Last updated to reflect repository state on this branch.*
