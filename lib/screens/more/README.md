# more

**Purpose**  
Settings stub exposing the theme switcher and placeholder toggles for future preferences (units, privacy, export/import).

**Contents & Key Files**
- [more_screen.dart](more_screen.dart): Scaffold with list tiles and the global `ThemeSwitcher`.

**How It Fits In**
- Entry point(s): GoRouter branch `/more` (`more` route) within bottom navigation shell.
- Upstream deps: `ThemeSwitcher` widget, Material components.
- Downstream consumers: Updates `themeModeProvider` when theme action invoked.

**State & Architecture**
- Pattern: Stateless screen; toggles currently stubbed (`onChanged` no-op or disabled).
- Main state owners: Theme mode provider (handled in `theme/mode_provider.dart`).
- Data flow: Theme button cycles mode via `ThemeSwitcher` → Riverpod provider → `IronPulseApp`.

**Public API (surface area)**
- Exposed widgets/classes: `MoreScreen`.
- Navigation: None—list items placeholders for future expansions.
- Events/commands: Theme icon toggles `nextThemeMode`; other switches currently disabled/informational.

**Data & Services**
- Models/DTOs: None.
- Repositories/services: None.
- External APIs/plugins: None.

**Configuration**
- Env/flavors: Could extend to surface flavor-specific toggles; currently uniform.
- Permissions: Privacy lock switch disabled; no biometric integration yet.
- Assets/localization: Static English copy.

**Testing**
- Coverage focus: Not covered by tests; rely on smoke tests.
- How to run: `flutter test` (includes app smoke test).
- Notable test helpers/mocks: N/A.

**Gotchas & Conventions**
- Keep placeholder actions disabled until features exist to avoid misleading users.
- Theme switch relies on Riverpod provider—ensure screen rebuild occurs when toggled.

**Quick Start**
- For dev work here: add actual preference providers and wire switches to Riverpod state.
- Example usage:
```dart
const MoreScreen();
```
