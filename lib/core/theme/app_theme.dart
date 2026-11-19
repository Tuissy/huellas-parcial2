// De Cupertino solo se importa la transición de pantallas estilo iOS.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

// Clase "abstract final": no se instancia; solo ofrece los métodos
// estáticos light() y dark() que usa el MaterialApp.
/// Tema visual (Material 3) de la aplicación en modo claro y oscuro.
///
/// La paleta sale de la temática de Huellas: el verde azulado del ícono de
/// la app, un tono cálido de atardecer para los acentos y fondos color
/// "papel", como las hojas de un diario.
abstract final class AppTheme {
  /// Color semilla: Material 3 genera toda la paleta a partir de él.
  static const Color seed = Color(0xFF2A7F7A);

  /// Acento cálido (atardecer).
  static const Color sunset = Color(0xFFE8914A);

  // Los dos temas usan la misma receta; solo cambia el brillo.
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// Construye el tema completo para el brillo indicado (claro u oscuro).
  static ThemeData _build(Brightness brightness) {
    // 1) Paleta de colores: se genera desde la semilla y luego se cambian
    //    los colores terciarios (tono atardecer) para cada modo.
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

    // 2) Tipografía: se parte del texto por defecto de Material 3 y con
    //    copyWith solo se cambia el grosor y el espaciado de los títulos.
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

    // 3) Tema final: se juntan paleta y tipografía, y se personaliza cada
    //    componente para que toda la app se vea coherente.
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: titles,
      scaffoldBackgroundColor: scheme.surface,
      // Barra superior del color del fondo, con un título grande y grueso.
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
      // Tarjetas sin sombra, con esquinas redondeadas y un borde suave.
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
      // Botón flotante y botones rellenos con forma de píldora.
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
      // Chips (etiquetas) con forma de píldora y borde.
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      // Campos de texto rellenos, con esquinas redondeadas y sin borde.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      // Los avisos SnackBar flotan sobre el contenido.
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      // Animación al cambiar de pantalla según la plataforma: transición
      // de desvanecido en Android y deslizamiento lateral en iOS.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
