import 'package:flutter/material.dart';
// flutter_localizations trae las traducciones de los textos internos
// de los widgets Material (calendarios, menús, botones) al español.
import 'package:flutter_localizations/flutter_localizations.dart';

// Importa la raíz de composición, el tema, el controlador de ajustes y
// el enrutador de la capa de presentación (rutas con nombre).
import 'core/di/app_dependencies.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'presentation/controllers/settings_controller.dart';
import 'presentation/routes/app_router.dart';
import 'presentation/routes/app_routes.dart';

// Es un StatefulWidget porque guarda estado propio que se crea una
// sola vez: el controlador de ajustes y la ruta inicial.
/// Widget raíz: configura tema, idioma y navegación por rutas con nombre.
class HuellasApp extends StatefulWidget {
  const HuellasApp({super.key});

  // createState crea el objeto State, que es donde vive la lógica real.
  @override
  State<HuellasApp> createState() => _HuellasAppState();
}

/// Estado del widget raíz: crea el [SettingsController] y decide si la
/// app arranca en la pantalla de bloqueo o en la de inicio.
class _HuellasAppState extends State<HuellasApp> {
  // Controlador de ajustes (tema y bloqueo). Es nullable porque se crea
  // en didChangeDependencies y no en el constructor.
  SettingsController? _settings;
  // late final: se asigna una sola vez más adelante y ya no cambia.
  late final String _initialRoute;

  // didChangeDependencies es el lugar recomendado para leer datos que
  // vienen del contexto, como AppScope. Puede llamarse varias veces.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si el controlador ya existe, se sale para no crearlo de nuevo.
    if (_settings != null) return;
    // Se crea el SettingsController pasándole el repositorio de ajustes
    // que viene de AppScope (inyección de dependencias por constructor).
    final settings = SettingsController(
      AppScope.of(context).settingsRepository,
    );
    _settings = settings;
    // Si el bloqueo biométrico está activado, la app abre primero la
    // pantalla de bloqueo (/lock); si no, entra directo al inicio (/).
    // La ruta inicial se decide una sola vez al arrancar.
    _initialRoute = settings.biometricLockEnabled
        ? AppRoutes.lock
        : AppRoutes.home;
  }

  // dispose libera el controlador cuando este widget se destruye, para
  // no dejar oyentes vivos en memoria.
  @override
  void dispose() {
    _settings?.dispose();
    super.dispose();
  }

  // build construye la app completa. Se vuelve a dibujar cuando cambian
  // los ajustes, por ejemplo al pasar de tema claro a oscuro.
  @override
  Widget build(BuildContext context) {
    // Aquí el controlador ya existe (se creó en didChangeDependencies),
    // por eso se puede usar el operador ! sin riesgo.
    final settings = _settings!;
    // SettingsScope comparte el controlador con todas las pantallas, y
    // ListenableBuilder redibuja el MaterialApp cada vez que el
    // controlador avisa de un cambio (ChangeNotifier, patrón observador).
    return SettingsScope(
      controller: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          // Nombre de la app y sin la etiqueta "DEBUG" en la esquina.
          title: 'Huellas',
          debugShowCheckedModeBanner: false,
          // Tema claro y tema oscuro; themeMode elige cuál usar según la
          // preferencia guardada por el usuario.
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          // Desplazamiento sin el efecto de "estirado" de Android 12 o
          // superior.
          scrollBehavior: const AppScrollBehavior(),
          // Idioma: se fuerza el español. Los delegados traducen los textos
          // internos de Material (calendarios, menús, botones).
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          // Rutas con nombre: la ruta inicial se calculó arriba; AppRouter
          // crea cada pantalla según su nombre y evita apilar rutas extra al
          // iniciar (así "atrás" no salta el bloqueo). routeObserver avisa a
          // las pantallas cuando vuelven a quedar visibles, para refrescar
          // sus datos.
          initialRoute: _initialRoute,
          onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
          onGenerateRoute: AppRouter.onGenerateRoute,
          navigatorObservers: [AppRouter.routeObserver],
        ),
      ),
    );
  }
}
