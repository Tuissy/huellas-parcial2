import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/app_dependencies.dart';
import 'core/theme/app_theme.dart';
import 'presentation/controllers/settings_controller.dart';
import 'presentation/routes/app_router.dart';
import 'presentation/routes/app_routes.dart';

/// Widget raíz: configura tema, idioma y navegación por rutas con nombre.
class HuellasApp extends StatefulWidget {
  const HuellasApp({super.key});

  @override
  State<HuellasApp> createState() => _HuellasAppState();
}

class _HuellasAppState extends State<HuellasApp> {
  SettingsController? _settings;
  late final String _initialRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settings != null) return;
    final settings = SettingsController(
      AppScope.of(context).settingsRepository,
    );
    _settings = settings;
    // La ruta inicial se decide una sola vez al arrancar.
    _initialRoute = settings.biometricLockEnabled
        ? AppRoutes.lock
        : AppRoutes.home;
  }

  @override
  void dispose() {
    _settings?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings!;
    return SettingsScope(
      controller: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'Huellas',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          initialRoute: _initialRoute,
          onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
          onGenerateRoute: AppRouter.onGenerateRoute,
          navigatorObservers: [AppRouter.routeObserver],
        ),
      ),
    );
  }
}
