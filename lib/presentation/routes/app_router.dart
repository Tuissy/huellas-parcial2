// ARCHIVO: app_router.dart. Es el centro de la navegación. Concepto: rutas con
// nombre y onGenerateRoute. MaterialApp nos entrega el nombre de cada ruta y
// aquí decidimos qué pantalla construir, con qué transición y validando sus
// argumentos.
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

// La clase es 'abstract final' porque solo tiene miembros estáticos: no hace
// falta crear objetos de ella.
/// Generador de rutas con nombre (`onGenerateRoute`).
///
/// Permite validar los argumentos de cada ruta y asignar una transición
/// distinta según el tipo de pantalla.
abstract final class AppRouter {
  // Concepto: RouteObserver / RouteAware para recargar al volver. Este
  // observador se registra en navigatorObservers de MaterialApp (app.dart) y
  // las pantallas se suscriben a él con el mixin RouteAwareRefresh.
  /// Notifica a las pantallas cuando vuelven a quedar visibles (por
  /// ejemplo, para recargar la lista al regresar del formulario).
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  // Concepto: onGenerateInitialRoutes para que el bloqueo no se pueda saltar.
  /// Evita que Flutter apile rutas intermedias al abrir la app en
  /// `/lock` (por defecto apilaría también `/`, y con el botón "atrás" se
  /// podría saltar el bloqueo biométrico).
  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) {
    // Devolvemos una lista con una sola ruta: la inicial que eligió app.dart
    // (bloqueo o inicio). Como la pila arranca solo con esa pantalla, debajo
    // del bloqueo no hay nada a lo que volver con 'atrás'. Reutilizamos
    // onGenerateRoute para no repetir lógica.
    return [onGenerateRoute(RouteSettings(name: initialRoute))];
  }

  /// Se ejecuta cada vez que se llama a Navigator.pushNamed (y para la ruta
  /// inicial). Recibe los RouteSettings, con el nombre y los argumentos, y
  /// devuelve la ruta que se va a mostrar.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // Guardamos los argumentos para comprobar su tipo con 'is' en cada caso.
    final args = settings.arguments;

    // Switch sobre el nombre de la ruta. En Dart 3 cada case termina solo, sin
    // break. Si un case no retorna porque los argumentos no son válidos, el
    // flujo sale del switch y llega a la pantalla de error del final.
    switch (settings.name) {
      // Bloqueo biométrico: aparece con desvanecido (FadePageRoute).
      case AppRoutes.lock:
        return FadePageRoute(
          settings: settings,
          builder: (_) => const LockScreen(),
        );

      // Inicio (lista de entradas): transición estándar de Material.
      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );

      // Detalle: solo se abre si el argumento es una DiaryEntry. Usa
      // desvanecido para que luzca la animación Hero de la foto.
      case AppRoutes.entryDetail:
        if (args is DiaryEntry) {
          return FadePageRoute(
            settings: settings,
            builder: (_) => EntryDetailScreen(entry: args),
          );
        }

      // Formulario: se desliza desde abajo (SlideUpPageRoute), como una tarea
      // nueva encima de la actual.
      case AppRoutes.entryForm:
        // Sin argumentos = nueva entrada; con DiaryEntry = edición.
        if (args == null || args is DiaryEntry) {
          return SlideUpPageRoute(
            settings: settings,
            builder: (_) => EntryFormScreen(initialEntry: args as DiaryEntry?),
          );
        }

      // Visor de fotos: necesita PhotoViewerArgs. La ruta no es opaca (opaque:
      // false) y tiene fondo negro, así durante la animación Hero la foto
      // crece sobre la pantalla anterior mientras el fondo se oscurece poco a
      // poco.
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

      // Mapa, ajustes y acerca de: secciones del menú lateral, con la
      // transición estándar de Material.
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
      // Reutilizamos ErrorView (state_views.dart) y mostramos el nombre de la
      // ruta que no se pudo abrir.
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
