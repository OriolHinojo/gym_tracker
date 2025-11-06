# lib

**Purpose**  
Root Flutter module wiring IronPulse’s UI shell, routing, state providers, and feature surfaces.

**Contents & Key Files**
- [main.dart](main.dart): Entry point wrapping `IronPulseApp` in a global `ProviderScope`.
- [app.dart](app.dart): Builds the `MaterialApp.router`, themes, and watches Riverpod providers.
- [router.dart](router.dart): Central `GoRouter` with bottom navigation shell and deep-link routes.
- [data/](data/): `LocalStore` JSON persistence plus repository interfaces.
- [services/](services/): Analytics service layer and mock service adapters.
- [screens/](screens/): Feature UIs for Home, Log, Progress, Library, and More tabs.
- [shared/](shared/) & [widgets/](widgets/): Cross-cutting view models, charts, dialogs, and helpers.
- [theme/](theme/): Material 3 theming, `ThemeSwitcher`, and mode provider.
- [models/](models/): Domain enums and plain-data classes used across features.

**How It Fits In**
- Entry point(s): `IronPulseApp` → bootstrapped by `main.dart` and exported to host platforms.
- Upstream deps: Flutter SDK, `flutter_riverpod`, `go_router`, `path_provider`, `fl_chart`, `intl`, `freezed_annotation`, `json_annotation`.
- Downstream consumers: Platform runners (android/ios/web/etc.), `test/` suites exercising `LocalStore`, analytics, and log flows.

**State & Architecture**
- Pattern: Riverpod providers for app-wide concerns plus stateful widgets for feature flows; no BLoC layer.
- Main state owners: `themeModeProvider`, `appRouterProvider`, `LocalStore.instance`, `AnalyticsService`, `LogScreen`’s editor state.
- Data flow: `LocalStore` (JSON disk) → services (`AnalyticsService`, progress calculators) → screens/widgets via `FutureBuilder`/`ValueListenableBuilder`; navigation driven by `GoRouter` branches.

**Public API (surface area)**
- Exposed widgets/classes: `IronPulseApp`, `ThemeSwitcher`, `SessionPreviewSheet`, `SessionHeaderCard`, `SessionExercisesList`, `ProgressLineChart`, `ProgressFilters`, `LocalStore`.
- Navigation: Named routes `home`, `log`, `progress`, `library`, `exerciseDetail`, `more`, `sessionDetail`, `workout`; deep links `/sessions/:id`, `/workout/:id` (extra map supports `templateId`/`editWorkoutId`).
- Events/commands: Imperative `LocalStore.instance.*` (init, CRUD, analytics helpers) plus `ValueNotifier` for preferred exercise updates.

**Data & Services**
- Models/DTOs: `models/models.dart`, `shared/session_detail.dart`, `shared/progress_types.dart`, `services/analytics/analytics_models.dart`.
- Repositories/services: `data/local/local_store.dart`, `data/contracts/repos.dart`, `services/analytics/analytics_service.dart`, `services/mocks/mock_services.dart`.
- External APIs/plugins: `path_provider` for file locations, `dart:io`/`dart:convert` for persistence, `fl_chart` only via custom painter wrappers (no direct dependency use yet).

**Configuration**
- Env/flavors: None; runtime theming controlled through `themeModeProvider` cycling system/light/dark.
- Permissions: Relies on default doc-directory access (`path_provider`); no additional manifest tweaks detected.
- Assets/localization: Material icons enabled; no custom assets or ARB bundles configured.

**Testing**
- Coverage focus: Analytics aggregation, local-store template lineage, and Log screen editor focus logic.
- How to run: `flutter test`
- Notable test helpers/mocks: `LocalStore.overrideAppDirectory`/`resetForTests`, Log screen debug APIs, analytics filters in `services/analytics`.

**Gotchas & Conventions**
- `LocalStore` asserts non-web usage and must be `init()`ed before reads; screens wrap calls in `FutureBuilder`.
- `LocalStore` persists workout/template linkage (`template_id`) for analytics—keep updates in sync with `_ensureTemplateMetadata`.
- `LogScreen` uses a `Ticker`; remember to dispose tickers when introducing new editors.
- Route extras are loose `Map` payloads—validate types before casting.

**Quick Start**
- For dev work here: `flutter run -d <device_id>` from repo root (ensures `LocalStore` seeds mock data).
- Example usage:
```dart
final router = ref.read(appRouterProvider);
router.go('/log');
```
