import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';

/// Punto de entrada de Huellas.
///
/// 1. Registra manejadores globales de errores (ningún error no controlado
///    cierra la app sin dejar rastro).
/// 2. Inicializa formatos de fecha en español.
/// 3. Construye las dependencias y arranca la interfaz.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerGlobalErrorHandlers();

  try {
    await initializeDateFormatting('es');
    final dependencies = await AppDependencies.create();
    runApp(AppScope(dependencies: dependencies, child: const HuellasApp()));
  } catch (error, stack) {
    developer.log('Fallo al iniciar la app', error: error, stackTrace: stack);
    runApp(_StartupErrorApp(onRetry: main));
  }
}

void _registerGlobalErrorHandlers() {
  // Errores dentro del framework (build, layout, paint).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    developer.log(
      'Error de Flutter',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  // Errores asíncronos no capturados (Futures, plugins).
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log('Error no controlado', error: error, stackTrace: stack);
    // También a la consola (logcat / Xcode) para poder diagnosticarlo.
    debugPrint('Error no controlado: $error\n$stack');
    return true; // Marcado como manejado: la app sigue viva.
  };
}

/// Pantalla mínima si la app no pudo inicializarse (p. ej. almacenamiento
/// lleno o corrupto). Permite reintentar en lugar de cerrarse.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo iniciar Huellas.\nRevisa el espacio disponible e intenta de nuevo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
