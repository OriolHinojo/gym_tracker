# contracts

**Purpose**  
Declares service-level abstractions for analytics-adjacent features (metrics calculations, training suggestions) to decouple UI from concrete providers.

**Contents & Key Files**
- [services.dart](services.dart): Interfaces `MetricsService`, `SuggestionEngine`, and helper `Point` class used for trend data.

**How It Fits In**
- Entry point(s): Imported by analytics mocks and future DI layers.
- Upstream deps: `lib/models/models.dart` for domain classes.
- Downstream consumers: `lib/services/mocks/mock_services.dart`, potential production service adapters.

**State & Architecture**
- Pattern: Pure abstract classes; implementations provide async behaviour.
- Main state owners: None—implementors manage state externally.
- Data flow: Contracts define how UI can request e1RM estimates, trend data, and next-target suggestions.

**Public API (surface area)**
- Exposed widgets/classes: `MetricsService`, `SuggestionEngine`, `Point`.
- Navigation: Not applicable.
- Events/commands: Async methods (`estimateE1RM`, `e1rmTrend`, `suggestNext`) represent service commands.

**Data & Services**
- Models/DTOs: Builds on `NextTarget`, `Point`, and existing domain models.
- Repositories/services: Planned integration point for cloud analytics/AI recommendations.
- External APIs/plugins: None—interfaces only.

**Configuration**
- Env/flavors: Implementations can vary per environment; contracts remain agnostic.
- Permissions: Not applicable.
- Assets/localization: Not relevant.

**Testing**
- Coverage focus: None yet; implementors should add tests verifying conformance.
- How to run: N/A (no concrete code).
- Notable test helpers/mocks: Use `MockMetricsService`/`MockSuggestionEngine` from `../mocks`.

**Gotchas & Conventions**
- `Point` uses `DateTime` X axis and double Y; keep consistent when plotting.
- Add new service capabilities here before wiring UI to maintain single source of truth.

**Quick Start**
- For dev work here: implement `MetricsService` using your analytics backend and register with DI.
- Example usage:
```dart
class ApiMetricsService implements MetricsService {
  @override
  Future<List<Point>> e1rmTrend(String exerciseId, {Duration? range}) async {
    // fetch and map response
  }
}
```
