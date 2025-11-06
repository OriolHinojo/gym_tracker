# local

**Purpose**  
Hosts the `LocalStore` singleton—an on-device JSON database that seeds demo data, persists workouts/exercises, and powers analytics queries.

**Contents & Key Files**
- [local_store.dart](local_store.dart): Complete implementation of the file-backed store, schema migrations, mock seeding, and helper APIs.

**How It Fits In**
- Entry point(s): `LocalStore.instance` → initialised lazily via `init()` before screens/services query data.
- Upstream deps: `dart:io`, `dart:convert`, `path_provider`, `flutter/foundation`.
- Downstream consumers: Home overview, Log editor, Library templates, Progress analytics, widget/unit tests.

**State & Architecture**
- Pattern: Singleton with cached `_db` Map and a `Completer` guarding async initialisation; exposes a `ValueNotifier<int?>` for preferred exercise updates.
- Main state owners: `_db` in memory, `_preferredExerciseId`, `_file` handle, `_overrideAppDir` for tests.
- Data flow: `init()` resolves storage directory → seeds or loads JSON → mutation helpers update in-memory map → `_save()` writes atomically.

**Public API (surface area)**
- Exposed widgets/classes: `LocalStore` with methods like `listExercisesRaw`, `listRecentWorkoutsRaw`, `saveWorkout`, `deleteWorkout`, `createWorkoutTemplate`.
- Navigation: Supplies IDs for GoRouter routes (`/sessions/:id`, `/log`, `/library/exercise/:id`); session previews rely on `loadSessionDetail`.
- Events/commands: `preferredExerciseIdListenable`, `createExercise`, `updateExercise`, `deleteExercise`, `setPreferredExercise`, `overrideAppDirectory`, `resetForTests`.

**Data & Services**
- Models/DTOs: Raw maps for `users`, `exercises`, `workouts`, `sets`, `workout_templates`; enriched helpers like `HomeStats`, `SetDraft`.
- Repositories/services: Backing store for `AnalyticsService` and `SessionDetail`; entry point for future repo adapters.
- External APIs/plugins: Uses `path_provider.getApplicationDocumentsDirectory()`; relies on `Ticker`-driven screens for live updates.

**Configuration**
- Env/flavors: Tests call `overrideAppDirectory`; otherwise writes to platform documents dir (non-web only).
- Permissions: Ensure mobile platforms grant file access; seeding fails on web (`assert(!kIsWeb)`).
- Assets/localization: JSON seeded programmatically; no asset bundle.

**Testing**
- Coverage focus: `test/local_store_template_test.dart` (template lineage), `test/analytics_service_test.dart`, `test/log_screen_focus_test.dart` (debug hooks).
- How to run: `flutter test test/local_store_template_test.dart`
- Notable test helpers/mocks: `resetForTests(deleteFile: true)`, `_templateIdNotSet`, ability to inject overrides for deterministic envs.

**Gotchas & Conventions**
- Always `await LocalStore.instance.init()` before use—habitually wrap calls in async builders.
- Schema migrations handled by `_ensureTemplateMetadata`; extend carefully when adding keys.
- `_save()` writes via temp file rename; maintain when introducing asynchronous mutations.
- `listLatestSetsForExerciseRaw` prioritises template-specific history—pass `templateId` when replaying templates.

**Quick Start**
- For dev work here: initialise once during app bootstrap or inside a Riverpod FutureProvider.
- Example usage:
```dart
await LocalStore.instance.init();
final workouts = await LocalStore.instance.listRecentWorkoutsRaw(limit: 5);
```
