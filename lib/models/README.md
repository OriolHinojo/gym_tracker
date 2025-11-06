# models

**Purpose**  
Defines domain enums and POJO-style classes used by services, contracts, and future data sources (exercises, workouts, sets, PRs, targets).

**Contents & Key Files**
- [enums.dart](enums.dart): Enumerations for equipment types, progression rules, perceived difficulty (`FeltFlag`), and PR categories.
- [models.dart](models.dart): Plain Dart classes (`Exercise`, `Workout`, `ExerciseInstance`, `SetEntry`, `PRRecord`, `NextTarget`) mirroring core gym concepts.

**How It Fits In**
- Entry point(s): Imported by service contracts and mock services; ready for future repository implementations.
- Upstream deps: None—pure Dart types.
- Downstream consumers: `services/contracts/services.dart`, `services/mocks/mock_services.dart`, `data/contracts/repos.dart`, potential API layers.

**State & Architecture**
- Pattern: Immutable data classes with required constructor parameters; no serialization helpers yet.
- Main state owners: Callers instantiate objects; no global singletons.
- Data flow: Intended to bridge `LocalStore`/future backends and UI via typed models.

**Public API (surface area)**
- Exposed widgets/classes: `Exercise`, `Workout`, `ExerciseInstance`, `SetEntry`, `PRRecord`, `NextTarget`, plus enums.
- Navigation: `Workout.id` aligns with `/sessions/:id`; other IDs map to library/log features.
- Events/commands: None—pure data containers.

**Data & Services**
- Models/DTOs: Domain classes capture metadata (progression rules, microplates, rest defaults).
- Repositories/services: Contracts & mocks reference these types; add adapters when moving beyond raw JSON maps.
- External APIs/plugins: Not applicable.

**Configuration**
- Env/flavors: No environment-specific behaviour.
- Permissions: None.
- Assets/localization: Not used.

**Testing**
- Coverage focus: Currently unused in tests; future repo tests should instantiate these classes for type safety.
- How to run: N/A (no dedicated tests); include in broader suites with `flutter test`.
- Notable test helpers/mocks: Use `MockMetricsService` suggestions referencing `NextTarget`.

**Gotchas & Conventions**
- IDs are strings (even when data store uses ints); ensure conversions when bridging with `LocalStore`.
- Constructors expect consistently typed lists (e.g., `variationTags`); validate input when mapping from JSON.
- Keep enums in sync with UI drop-down options (e.g., equipment types).

**Quick Start**
- For dev work here: create adapters mapping `LocalStore` maps to `Exercise` et al. before introducing network storage.
- Example usage:
```dart
final exercise = Exercise(
  id: 'bench_press',
  name: 'Bench Press',
  equipment: Equipment.barbell,
  primaryMuscles: ['chest', 'triceps'],
  variationTags: const ['flat'],
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```
