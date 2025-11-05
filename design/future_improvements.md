# 🚀 IronPulse — Future Enhancements Backlog

> Use this backlog as the implementation blueprint for upcoming iterations. Each item captures the current pain point, the desired experience, and concrete requirements so the work can be scoped without reopening discovery.

---

## 1) Template Lineage & Repeatable Sessions

- **Problem today**  
  Workout templates only store exercise IDs. When a user previews a template or repeats it, the UI guesses weights from the most recent sets logged for each exercise (any session). There is no way to answer “What did I lift the last time I ran *this* template?” or to build streak stats per routine.

- **Proposed solution**  
  Persist template metadata alongside workouts/sets so the system can track runs of a specific template, populate previews with the last template-specific attempt, and unlock analytics such as completion streaks.

- **Requirements**
  - Extend `LocalStore.saveWorkout` to accept an optional `template_id`; persist it on the workout record and cascade to sets.
  - Migrate existing data: introduce a lightweight migration step that backfills `template_id` with `null` for historical workouts.
  - Update `LogScreen` save flow to pass the `templateId` when a session originates from templates (including edits/duplicates).
  - Update `listLatestSetsForExerciseRaw` (or add a new API) that fetches the latest sets *per template*; fall back to global history if none exist.
  - Surface template-aware history in:
    - Library template preview (primary scenario).
    - Log screen placeholders when repeating a template.
  - Add unit tests covering template-save and retrieval flows.

---

## 2) Workout Logging UX Polish

- **Problem today**  
  Logging is functional but keystroke-heavy. Users have to manually focus inputs, add warm-ups, and track rest time themselves. This slows down at-gym usage.

- **Proposed solution**  
  Introduce targeted workflow optimisations that reduce taps and provide optional structure without forcing advanced tracking on every user.

- **Requirements**
  - Auto-focus the weight field of the first empty set when an exercise expands; move to the next field on “enter”.
  - Allow quick duplication of the previous set (`+ Same As Last`) with a single tap.
  - Provide optional set-level tags (Warm-up, Drop set, AMRAP) that persist in `LocalStore` and display in previews.
  - Integrate a per-exercise rest timer:
    - Tap “Start Rest” to begin a countdown (pre-filled with last rest length).
    - Visual warning when rest exceeds target.
  - Ensure timers pause when the user leaves the log screen.
  - Update save validation to include the new fields.
  - Add widget tests covering the focus/duplication behaviours.

---

## 3) Post-Session Feedback Loop

- **Problem today**  
  Completing a workout only triggers a snackbar. Users receive no insight into progression or guidance on what to do next.

- **Proposed solution**  
  Present a recap sheet summarising the session, comparing it with the previous run, and offering sub-actions (duplicate, edit notes, schedule reminders).

- **Requirements**
  - After `saveWorkout` succeeds, show a modal:
    - Total volume, top PRs, duration, template (if any).
    - Comparison vs. last time (weight delta, rep delta).
    - Buttons: `Duplicate Next Week`, `Edit Notes`, `Dismiss`.
  - Store workout duration and optional perceived exertion to feed comparisons.
  - Wire recap actions:
    - `Duplicate Next Week` schedules an entry in a lightweight reminders table.
    - `Edit Notes` reopens the log screen with the saved workout.
  - Add analytics hooks for completion stats (even if only logged to console initially).

---

## 4) Insights & Motivation Layer

- **Problem today**  
  Home and Progress screens offer basic numbers but no storytelling (streaks, PRs, plateaus).

- **Proposed solution**  
  Build a reusable insights service that surfaces meaningful trends and nudges users to stay consistent.

- **Requirements**
  - Implement a service (can start as a new class in `lib/services/`) that calculates:
    - Weekly streaks, longest streak, days since last session.
    - Recent PRs (per exercise and per template).
    - Volume trends (rolling 4-week comparison).
  - Expose new widgets on Home:
    - Streak badge (primary CTA).
    - “Recent PRs” horizontal list.
  - Extend Progress screen with filters for template, muscle group, and rep range.
  - Add unit tests around the insight calculations to guard against off-by-one errors.

---

## 5) Sharing & Collaboration

- **Problem today**  
  Workouts live locally. There is no easy way to share a routine with a coach or sync between devices.

- **Proposed solution**  
  Introduce portable exports and opt-in sharing features while keeping privacy under user control.

- **Requirements**
  - Add export/import endpoints in `LocalStore` (JSON payload containing templates, workouts, and exercises).
  - Build a share sheet for templates (e.g., QR code or file export).
  - Handle import conflicts (duplicate exercise names, IDs) gracefully via merge dialogs.
  - Provide a “coach mode” toggle that reveals a read-only view optimised for showing someone else your session.
  - Document data format and versioning in `design/`.

---

## 6) Tooling, QA, and Accessibility

- **Problem today**  
  Formatting requires manual fixes, testing is minimal, and accessibility has not been audited.

- **Proposed solution**  
  Tighten the development workflow and ensure the app is usable for a broader audience.

- **Requirements**
  - Fix the CLI formatting issue (`/usr/bin/env bash\r`) and add a project `format.sh` script so contributors can run `flutter format` reliably.
  - Introduce GitHub Actions (or similar) to run `flutter analyze`, unit/widget tests, and formatting checks.
  - Expand widget tests to cover:
    - Session preview sheet (header chips, expanded sets).
    - Library template preview (ensuring latest sets appear).
  - Perform an accessibility pass:
    - Ensure all actionable icons have tooltips/semantics.
    - Provide large-text and high-contrast themes; verify with Flutter’s accessibility inspector.
  - Document QA checklists in `design/qa_checklist.md` (new file) when this work begins.

---

Keep this backlog up to date: when an item ships, move it into `design/design.md` (current state) and prune the completed entry here.

