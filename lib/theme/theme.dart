// lib/theme/theme.dart
import 'package:flutter/material.dart';

/// Try a few seeds:
/// - Violet/Indigo: 0xFF6D5DF6 (current)
/// - Teal:          0xFF14B8A6
/// - Electric Blue: 0xFF0EA5E9
/// - Punchy Pink:   0xFFEC4899
const Color _seed = Color(0xFF6D5DF6);

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

  // Brand extension: handy gradient + status colors accessible via Theme.of(context).extension<BrandColors>()!
  final brand = BrandColors(
    gradientStart: scheme.primary,
    gradientEnd: scheme.tertiary,
    success: const Color(0xFF22C55E),
    warning: const Color(0xFFF59E0B),
    danger:  const Color(0xFFEF4444),
  );

  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[brand],

    // Typography accents (crisper section titles)
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),

    // AppBar — flat, colorful surfaces
    appBarTheme: base.appBarTheme.copyWith(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),

    // NavigationBar — clearer selection pill + toned icons
    navigationBarTheme: base.navigationBarTheme.copyWith(
      elevation: 0,
      height: 64,
      indicatorColor: scheme.primaryContainer.withOpacity(0.65),
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

    // Cards — soft, rounded, no muddy surface tint
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),

    // Buttons — confident shapes
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // FAB — vivid by default
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      elevation: 0,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      extendedTextStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),

    // Chips — tighter, colorful
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selectedColor: scheme.primaryContainer,
      labelStyle: base.textTheme.labelLarge,
    ),

    // Inputs — subtle fill for elegance
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      isDense: true,
      filled: true,
      fillColor: brightness == Brightness.dark
          ? scheme.surfaceContainerHighest.withOpacity(0.18)
          : scheme.surfaceContainerHighest.withOpacity(0.08),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),

    // Dividers — soft & spaced
    dividerTheme: base.dividerTheme.copyWith(
      space: 16,
      thickness: 1,
      color: scheme.outlineVariant.withOpacity(0.35),
    ),

    // Bottom sheets & dialogs — rounded, clean
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      elevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      elevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
  );
}

/// Lightweight brand “palette” you can use across widgets (for gradients, status colors, etc).
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.gradientStart,
    required this.gradientEnd,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color gradientStart;
  final Color gradientEnd;
  final Color success;
  final Color warning;
  final Color danger;

  @override
  BrandColors copyWith({
    Color? gradientStart,
    Color? gradientEnd,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return BrandColors(
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  BrandColors lerp(ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
    }
}
