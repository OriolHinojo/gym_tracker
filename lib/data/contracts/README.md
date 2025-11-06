# contracts

**Purpose**  
Defines abstract repository interfaces for exercises, workouts, sets, PRs, and next targets—serving as a boundary between UI/services and future data backends.

**Contents & Key Files**
- [repos.dart](repos.dart): Interfaces `ExerciseRepo`, `WorkoutRepo`, `SetRepo`, `PRRepo`, `NextTargetRepo` with minimal CRUD/watch methods.

**How It Fits In**
- Entry point(s): Consumed by potential DI layers; currently referenced by service mocks and future architecture hooks.
- Upstream deps: `lib/models/models.dart` for typed entities.
- Downstream consumers: Mock services (`lib/services/mocks`), analytics contracts, prospective repository implementations.

**State & Architecture**
- Pattern: Pure abstract classes outlining async fetch/update signatures and stream-based observers.
- Main state owners: None—implementers provide concrete storage.
- Data flow: Intended to funnel data from local/remote sources into typed models before reaching UI.

**Public API (surface area)**
- Exposed widgets/classes: `ExerciseRepo`, `WorkoutRepo`, `SetRepo`, `PRRepo`, `NextTargetRepo`, `Point`.
- Navigation: Workout IDs align with `/sessions/:id`; exercise IDs tie into Library/Log flows.
- Events/commands: Streams (`watchAll`, `watchByExerciseInstance`) signal data changes to subscribers.

**Data & Services**
- Models/DTOs: Leverages `Exercise`, `Workout`, `SetEntry`, `PRRecord`, `NextTarget`.
- Repositories/services: Contract layer above `LocalStore` or remote APIs; meant to back go-forward implementation.
- External APIs/plugins: Not applicable (interfaces only).

**Configuration**
- Env/flavors: Implementors decide; contracts remain environment-agnostic.
- Permissions: None.
- Assets/localization: Not relevant.

**Testing**
- Coverage focus: None yet; write adapter tests when implementing repositories.
- How to run: N/A—interfaces only.
- Notable test helpers/mocks: Pair with `services/mocks/mock_services.dart` when prototyping.

**Gotchas & Conventions**
- IDs are typed as `String` within models—store adapters must bridge integer IDs from `LocalStore`.
- Keep streams hot and well-behaved (emit initial snapshot, close on dispose).
- Add new domain concepts here before wiring UI to ensure consistency.

**Quick Start**
- For dev work here: implement these interfaces using `LocalStore` or a remote API to unlock typed data flows.
- Example usage:
```dart
class LocalExerciseRepo implements ExerciseRepo {
  @override
  Future<List<Exercise>> getAll() async => /* map from LocalStore */;
  // ...
}
```
