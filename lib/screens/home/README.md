# home

**Purpose**  
Landing dashboard summarising weekly activity, recent sessions, and highlights while exposing quick navigation to logging and analytics.

**Contents & Key Files**
- [home_screen.dart](home_screen.dart): Builds the overview page with summary grid, recent session list, and highlights card.

**How It Fits In**
- Entry point(s): GoRouter route `/` (`home`); appears inside the bottom navigation shell.
- Upstream deps: `LocalStore` for stats and recent workouts, `SessionDetail` loader, shared widgets (`SessionPreviewSheet`), `BrandColors`.
- Downstream consumers: Navigates to `/sessions/:id`, `/progress`, `/log`; interacts with `LogScreen` via FAB.

**State & Architecture**
- Pattern: Stateless widget with async builders (`FutureBuilder`, `ValueListenableBuilder`).
- Main state owners: `LocalStore`’s `preferredExerciseIdListenable` informs overview grid.
- Data flow: `ValueListenableBuilder` → fetch `HomeStats` via `LocalStore.getHomeStats()` → render `_SummaryGrid`; recent workouts fetched via `listRecentWorkoutsRaw`.

**Public API (surface area)**
- Exposed widgets/classes: `HomeScreen`.
- Navigation: FAB uses `context.go('/log')`; list tiles `context.push('/sessions/<id>')`; stat cards link to `/progress` or `/`.
- Events/commands: Recent session tap opens the detail screen (no separate preview); highlight actions placeholder (`See all` button).

**Data & Services**
- Models/DTOs: `HomeStats` (defined in `LocalStore`), `SessionDetail`.
- Repositories/services: Reads from `LocalStore`; no direct analytics service usage.
- External APIs/plugins: None beyond Flutter material.

**Configuration**
- Env/flavors: None; relies on seeded data when no user workouts exist.
- Permissions: Indirect via `LocalStore` (disk access).
- Assets/localization: Static English copy for highlights.

**Testing**
- Coverage focus: None specific; behaviour indirectly validated by `local_store` tests.
- How to run: `flutter test` (no dedicated suite).
- Notable test helpers/mocks: During tests, override `LocalStore` directory for deterministic stats.

**Gotchas & Conventions**
- Ensure `LocalStore.init()` completes before navigating to Home; otherwise FutureBuilders show loaders.
- `_SummaryGrid` adapts layout using width breakpoints; keep consistent when adding cards.
- Highlights list currently static; update copy or drive from analytics when available.

**Quick Start**
- For dev work here: tweak `HomeStats` in `LocalStore` to adjust dashboard metrics.
- Example usage:
```dart
context.push('/sessions/$sessionId');
```
