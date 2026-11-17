import 'package:flutter/material.dart';

import '../../domain/entities/diary_entry.dart';
import '../screens/about/about_screen.dart';
import '../screens/detail/entry_detail_screen.dart';
import '../screens/form/entry_form_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/lock/lock_screen.dart';
import '../screens/map/entries_map_screen.dart';
import '../screens/photo/photo_viewer_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../widgets/state_views.dart';
import 'app_routes.dart';
import 'page_transitions.dart';

/// Generador de rutas con nombre (`onGenerateRoute`).
///
/// Permite validar los argumentos de cada ruta y asignar una transición
/// distinta según el tipo de pantalla.
abstract final class AppRouter {
  /// Notifica a las pantallas cuando vuelven a quedar visibles (por
  /// ejemplo, para recargar la lista al regresar del formulario).
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  /// Evita que Flutter apile rutas intermedias al abrir la app en
  /// `/lock` (por defecto apilaría también `/`, y con el botón "atrás" se
  /// podría saltar el bloqueo biométrico).
  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) {
    return [onGenerateRoute(RouteSettings(name: initialRoute))];
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case AppRoutes.lock:
        return FadePageRoute(
          settings: settings,
          builder: (_) => const LockScreen(),
        );

      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );

      case AppRoutes.entryDetail:
        if (args is DiaryEntry) {
          return FadePageRoute(
            settings: settings,
            builder: (_) => EntryDetailScreen(entry: args),
          );
        }

      case AppRoutes.entryForm:
        // Sin argumentos = nueva entrada; con DiaryEntry = edición.
        if (args == null || args is DiaryEntry) {
          return SlideUpPageRoute(
            settings: settings,
            builder: (_) => EntryFormScreen(initialEntry: args as DiaryEntry?),
          );
        }

      case AppRoutes.photoViewer:
        if (args is PhotoViewerArgs) {
          return FadePageRoute(
            settings: settings,
            opaque: false,
            barrierColor: Colors.black,
            duration: const Duration(milliseconds: 350),
            builder: (_) => PhotoViewerScreen(args: args),
          );
        }

      case AppRoutes.map:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const EntriesMapScreen(),
        );

      case AppRoutes.settings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );

      case AppRoutes.about:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AboutScreen(),
        );
    }

    // Ruta desconocida o argumentos inválidos: pantalla de error amigable
    // en lugar de una excepción.
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Página no encontrada')),
        body: ErrorView(
          message: 'No pudimos abrir "${settings.name}".',
          icon: Icons.explore_off_outlined,
        ),
      ),
    );
  }
}
