# 🚀 IronPulse — Future Enhancements Backlog

> Use this backlog as the implementation blueprint for upcoming iterations. Each item captures the current pain point, the desired experience, and concrete requirements so the work can be scoped without reopening discovery.

---

## 1) Post-Session Feedback Loop

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

## 2) Insights & Motivation Layer

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

## 3) Sharing & Collaboration

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

## 4) Tooling, QA, and Accessibility

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
