# data

**Purpose**  
Provides persistence abstractions—JSON-backed storage plus repository contracts that feed UI, analytics, and editor flows.

**Contents & Key Files**
- [contracts/repos.dart](contracts/repos.dart): Abstract repos for exercises, workouts, sets, PRs, and next targets; used as extension points when replacing the demo store.
- [local/local_store.dart](local/local_store.dart): Singleton `LocalStore` that seeds mock data, reads/writes disk JSON, and exposes imperative APIs plus list/stream utilities.

**How It Fits In**
- Entry point(s): `LocalStore.instance` → initialised lazily by screens/services before data reads.
- Upstream deps: `dart:io`, `dart:convert`, `path_provider`, `flutter/foundation` for `ValueNotifier`.
- Downstream consumers: Home/Log/Library/Progress screens, `AnalyticsService`, `SessionDetail` loader, unit/widget tests.

**State & Architecture**
- Pattern: Singleton service with manual futures and a `ValueNotifier<int?>` (`preferredExerciseId`); no Riverpod provider wrapper yet.
- Main state owners: Internal `_db` map cached in memory, plus `_preferredExerciseId` for home overview.
- Data flow: JSON file ⇄ `LocalStore` in-memory cache → synchronous map/list cloning → UI via `FutureBuilder`/`ValueListenableBuilder`.

**Public API (surface area)**
- Exposed widgets/classes: `LocalStore` (methods `init`, `listExercisesRaw`, `saveWorkout`, `listRecentWorkoutsRaw`, `createWorkoutTemplate`, etc.).
- Navigation: Indirect—helpers like `loadSessionDetail` rely on route IDs from `GoRouter`.
- Events/commands: `preferredExerciseIdListenable`, CRUD methods (`createExercise`, `updateExercise`, `deleteWorkout`, `saveWorkout`) emit persistence side-effects.

**Data & Services**
- Models/DTOs: Works with raw `Map<String, dynamic>` rows matching the seeded schema; interoperates with `shared/session_detail.dart`.
- Repositories/services: Contracts in `contracts/repos.dart` outline future implementations for remote or database adapters.
- External APIs/plugins: Uses `path_provider` to resolve app document directory; `dart:io` ensures cross-platform file handling (non-web).

**Configuration**
- Env/flavors: None; optionally override storage path in tests with `overrideAppDirectory`.
- Permissions: Relies on platform document-directory access; ensure Android/iOS storage permissions remain default.
- Assets/localization: Not applicable—data seeded programmatically.

**Testing**
- Coverage focus: Template lineage (`test/local_store_template_test.dart`), analytics aggregation seeding (`test/analytics_service_test.dart`), Log screen editor harness.
- How to run: `flutter test test/local_store_template_test.dart`
- Notable test helpers/mocks: `LocalStore.resetForTests`, `_templateIdNotSet` sentinel, seeded dataset for predictable volumes.

**Gotchas & Conventions**
- `init()` must run before any query; repeated calls reuse a `Completer` but failures propagate.
- File backend disabled on web (`assert(!kIsWeb)`); guard alternative providers when targeting Flutter Web.
- `_ensureTemplateMetadata` backfills legacy JSON—preserve this when tweaking schema migrations.
- CRUD helpers always clone lists before mutation to avoid shared-map aliasing.

**Quick Start**
- For dev work here: call `await LocalStore.instance.init();` early (e.g., inside a FutureProvider) to warm the cache.
- Example usage:
```dart
final workouts = await LocalStore.instance.listRecentWorkoutsRaw(limit: 5);
```
