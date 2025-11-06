# theme

**Purpose**  
Centralises Material 3 theming, reusable brand extensions, and the Riverpod-controlled theme mode switch leveraged across the app.

**Contents & Key Files**
- [theme.dart](theme.dart): Builds light/dark `ThemeData`, defines `BrandColors` extension, and customises navigation/buttons/typography.
- [mode_provider.dart](mode_provider.dart): Riverpod `StateProvider<ThemeMode>` plus `nextThemeMode` helper for cycling system/light/dark.
- [theme_switcher.dart](theme_switcher.dart): `ThemeSwitcher` widget bound to the provider, rendering the app bar toggle in More and elsewhere.

**How It Fits In**
- Entry point(s): `IronPulseApp` watches `themeModeProvider` and applies `buildLightTheme`/`buildDarkTheme`; `ThemeSwitcher` exposed on settings screen.
- Upstream deps: Flutter `Material`, `flutter_riverpod`.
- Downstream consumers: Every screen via `MaterialApp.router`, `MoreScreen` action bar, widgets accessing `BrandColors`.

**State & Architecture**
- Pattern: Provider-based theme mode state; pure functions for theme construction.
- Main state owners: `themeModeProvider`, Riverpod `StateController`.
- Data flow: User taps `ThemeSwitcher` → `nextThemeMode` → provider updates → `MaterialApp.router` rebuild.

**Public API (surface area)**
- Exposed widgets/classes: `buildLightTheme`, `buildDarkTheme`, `BrandColors`, `themeModeProvider`, `nextThemeMode`, `ThemeSwitcher`.
- Navigation: None; UI component sits in app bar actions.
- Events/commands: `ThemeSwitcher`’s `IconButton` writes to `themeModeProvider.notifier`.

**Data & Services**
- Models/DTOs: `BrandColors` (`ThemeExtension`) adds gradient/status colours accessible via `Theme.of(context).extension<BrandColors>()`.
- Repositories/services: Not applicable.
- External APIs/plugins: Utilises Material 3 features (NavigationBar, ColorScheme).

**Configuration**
- Env/flavors: No environment-specific themes; adjust `_seed` or extend `BrandColors` for branding variants.
- Permissions: None.
- Assets/localization: Uses default Material fonts/icons.

**Testing**
- Coverage focus: Currently untested; rely on widget smoke tests to catch regressions (`test/widget_test.dart`).
- How to run: `flutter test test/widget_test.dart`
- Notable test helpers/mocks: N/A.

**Gotchas & Conventions**
- Theme uses `useMaterial3: true`; ensure custom widgets align with Material 3 spacing & semantics.
- `BrandColors` must be registered in both light and dark themes; add to `extensions` array when extending.
- `ThemeSwitcher` depends on `ThemeMode` icon mapping—update tooltip/icon pairs when adding modes.

**Quick Start**
- For dev work here: tweak `_seed` in `theme.dart`, hot-restart to preview new palettes.
- Example usage:
```dart
ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
```
