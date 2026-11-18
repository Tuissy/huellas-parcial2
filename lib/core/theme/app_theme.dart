import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Tema visual (Material 3) de la aplicación en modo claro y oscuro.
///
/// La paleta sale de la temática de Huellas: el verde azulado del ícono de
/// la app, un tono cálido de atardecer para los acentos y fondos color
/// "papel", como las hojas de un diario.
abstract final class AppTheme {
  static const Color seed = Color(0xFF2A7F7A);

  /// Acento cálido (atardecer).
  static const Color sunset = Color(0xFFE8914A);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final scheme = base.copyWith(
      tertiary: isLight ? sunset : const Color(0xFFF6B47A),
      onTertiary: isLight ? Colors.white : const Color(0xFF3B2410),
      tertiaryContainer: isLight
          ? const Color(0xFFFFE6D1)
          : const Color(0xFF5A3A1E),
      onTertiaryContainer: isLight
          ? const Color(0xFF3B2410)
          : const Color(0xFFFFE6D1),
      // Fondo color papel en modo claro.
      surface: isLight ? const Color(0xFFFBFAF6) : base.surface,
    );

    // Títulos más marcados, como los encabezados de un diario.
    final baseText = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
    ).textTheme;
    final titles = baseText.copyWith(
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: titles,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 2,
        titleTextStyle: TextStyle(
          fontSize: 22,
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: isLight ? Colors.white : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
