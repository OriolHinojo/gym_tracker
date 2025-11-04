import 'package:flutter/material.dart';

const Color _seed = Color(0xFF3E8E7E); // your brand color

ThemeData buildLightTheme() => _buildTheme(Brightness.light);
ThemeData buildDarkTheme()  => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  return base.copyWith(
    // Typography accents
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),

    // AppBar
    appBarTheme: base.appBarTheme.copyWith(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),

    // NavigationBar
    navigationBarTheme: base.navigationBarTheme.copyWith(
      elevation: 0,
      height: 64,
      indicatorColor: scheme.primaryContainer.withOpacity(0.55),
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        );
      }),
    ),

    // Cards
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
    ),

    // ListTile
    listTileTheme: base.listTileTheme.copyWith(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      iconColor: scheme.onSurfaceVariant,
    ),

    // Buttons
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // FAB
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      elevation: 0,
      foregroundColor: scheme.onPrimary,
      backgroundColor: scheme.primary,
      extendedTextStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),

    // Inputs
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      border: const OutlineInputBorder(),
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withOpacity(
        brightness == Brightness.dark ? 0.16 : 0.06,
      ),
    ),

    // Dividers
    dividerTheme: base.dividerTheme.copyWith(
      space: 16,
      thickness: 1,
      color: scheme.outlineVariant.withOpacity(0.4),
    ),

    // Sheets/dialogs
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      elevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      elevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
