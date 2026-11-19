// Archivo de arranque de Huellas. Aquí empieza la ejecución: se preparan
// los manejadores de errores, las fechas en español y las dependencias
// antes de dibujar la primera pantalla.
// - dart:developer: para escribir los errores en el log.
// - dart:ui: da acceso a PlatformDispatcher (errores asíncronos).
// - intl: datos de fechas en español (nombres de días y meses).
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

// Archivos propios: el widget raíz y la raíz de composición.
import 'app.dart';
import 'core/di/app_dependencies.dart';

// main es async porque antes de mostrar la interfaz hay que esperar
// tareas asíncronas, como abrir las preferencias o ubicar carpetas.
/// Punto de entrada de Huellas.
///
/// 1. Registra manejadores globales de errores (ningún error no controlado
///    cierra la app sin dejar rastro).
/// 2. Inicializa formatos de fecha en español.
/// 3. Construye las dependencias y arranca la interfaz.
Future<void> main() async {
  // Prepara el motor de Flutter antes de usar plugins (preferencias,
  // carpetas del sistema) fuera de runApp. Justo después se registran los
  // manejadores globales de errores, lo más temprano posible.
  WidgetsFlutterBinding.ensureInitialized();
  _registerGlobalErrorHandlers();

  // Manejo global de errores con try-catch: todo el arranque va dentro
  // del try. Si algo falla, la app no se cierra; muestra una pantalla de
  // error con la opción de reintentar.
  try {
    // Carga los nombres de días y meses en español para el paquete intl.
    await initializeDateFormatting('es');
    // Crea todas las dependencias: repositorios y servicios concretos.
    final dependencies = await AppDependencies.create();
    // runApp dibuja la interfaz. AppScope envuelve a HuellasApp para que
    // cualquier pantalla pueda pedir sus dependencias desde el contexto.
    runApp(AppScope(dependencies: dependencies, child: const HuellasApp()));
  } catch (error, stack) {
    // Si el arranque falla, se registra el error con su traza y se
    // muestra una app mínima de error; su botón "Reintentar" vuelve a
    // ejecutar main.
    developer.log('Fallo al iniciar la app', error: error, stackTrace: stack);
    runApp(_StartupErrorApp(onRetry: main));
  }
}

/// Registra los manejadores globales de errores de toda la aplicación.
///
/// Flutter tiene dos caminos de error distintos y aquí se cubren ambos,
/// para que ningún fallo pase en silencio ni cierre la app.
void _registerGlobalErrorHandlers() {
  // 1) FlutterError.onError atrapa los errores que ocurren mientras
  //    Flutter construye o dibuja widgets. Se muestran en consola con
  //    presentError y además se guardan en el log.
  // Errores dentro del framework (build, layout, paint).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    developer.log(
      'Error de Flutter',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  // 2) PlatformDispatcher.onError atrapa los errores asíncronos que
  //    nadie capturó con try-catch. Se registran en el log y en la
  //    consola, y al devolver true se le indica a Flutter que el error
  //    ya fue manejado.
  // Errores asíncronos no capturados (Futures, plugins).
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log('Error no controlado', error: error, stackTrace: stack);
    // También a la consola (logcat / Xcode) para poder diagnosticarlo.
    debugPrint('Error no controlado: $error\n$stack');
    return true; // Marcado como manejado: la app sigue viva.
  };
}

// Pantalla de respaldo: es una app aparte, muy simple y sin
// dependencias, para que pueda mostrarse aunque todo lo demás falle.
/// Pantalla mínima si la app no pudo inicializarse (p. ej. almacenamiento
/// lleno o corrupto). Permite reintentar en lugar de cerrarse.
class _StartupErrorApp extends StatelessWidget {
  // Recibe por constructor la acción del botón "Reintentar" (en main se
  // le pasa la propia función main).
  const _StartupErrorApp({required this.onRetry});

  /// Acción que se ejecuta al pulsar "Reintentar".
  final Future<void> Function() onRetry;

  // build arma la pantalla: ícono de error, mensaje y botón, centrados.
  @override
  Widget build(BuildContext context) {
    // Usa su propio MaterialApp porque la app principal no llegó a
    // crearse; así tiene tema Material y puede dibujar el Scaffold.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícono rojo de error y un mensaje que sugiere revisar el
                // espacio disponible.
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
                // Al pulsarlo se ejecuta onRetry: se vuelve a intentar
                // el arranque completo (main).
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
