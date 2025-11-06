# mocks

**Purpose**  
Provides deterministic mock implementations of service contracts so UI and tests can run without real analytics backends.

**Contents & Key Files**
- [mock_services.dart](mock_services.dart): `MockMetricsService` and `MockSuggestionEngine` returning synthetic trends, e1RM estimates, and next-target recommendations.

**How It Fits In**
- Entry point(s): Import when stubbing `MetricsService`/`SuggestionEngine` for demos or widget tests.
- Upstream deps: `lib/models/models.dart`, `services/contracts/services.dart`.
- Downstream consumers: Progress UI prototypes, potential storybook/demo environments.

**State & Architecture**
- Pattern: Stateless classes with deterministic outputs (`Random(42)`).
- Main state owners: None—methods compute results on the fly.
- Data flow: UI calls mock service methods → returns predictable lists for charts or suggestions.

**Public API (surface area)**
- Exposed widgets/classes: `MockMetricsService`, `MockSuggestionEngine`.
- Navigation: Not applicable.
- Events/commands: `estimateE1RM`, `e1rmTrend`, `volumeTrend`, `suggestNext`.

**Data & Services**
- Models/DTOs: Returns `Point` sequences and `NextTarget` entities.
- Repositories/services: Stand-in for real analytics engines; pair with contracts for dependency injection.
- External APIs/plugins: Uses `dart:math` for deterministic randomness only.

**Configuration**
- Env/flavors: No configuration; replace with production services in release builds.
- Permissions: None.
- Assets/localization: Not relevant.

**Testing**
- Coverage focus: Indirectly used by feature tests; ensures UI charts have data without hitting real APIs.
- How to run: `flutter test` (no dedicated specs).
- Notable test helpers/mocks: `MockMetricsService` seeded with constant Random; adjust seed if you need variance.

**Gotchas & Conventions**
- Keep Random seed stable to ensure golden tests remain deterministic.
- Suggestion engine currently returns constant +2.5kg recommendation—adapt when adding richer logic.
- Ensure mock trends match expected point counts when writing UI assertions.

**Quick Start**
- For dev work here: register mock instances in your DI container during development builds.
- Example usage:
```dart
final metrics = MockMetricsService();
final trend = await metrics.volumeTrend('bench_press');
```
