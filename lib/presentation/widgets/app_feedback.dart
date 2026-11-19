// ARCHIVO: app_feedback.dart. Concepto: AppFeedback, SnackBar o diálogo según
// el tipo de error (pattern matching sobre la clase sellada AppException).
// Todas las pantallas usan estos métodos, así los mensajes se ven igual en
// toda la app.
import 'package:flutter/material.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/errors/app_exception.dart';

/// Retroalimentación al usuario (SnackBars y diálogos) unificada.
///
/// Traduce cada tipo de [AppException] a la mejor respuesta de UI:
/// * Permiso bloqueado → diálogo con botón "Abrir ajustes".
/// * GPS apagado → diálogo con botón "Activar ubicación".
/// * Resto → SnackBar con el mensaje.
abstract final class AppFeedback {
  /// Muestra un SnackBar con el mensaje y un ícono opcional.
  static void showMessage(
    BuildContext context,
    String message, {
    IconData? icon,
  }) {
    // maybeOf devuelve null si no hay ScaffoldMessenger; en ese caso salimos
    // sin hacer nada para no provocar un error.
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    // Operador cascada (..): primero ocultamos el SnackBar actual para que no
    // se acumulen y luego mostramos el nuevo.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              // Si hay ícono, se agrega con un espacio. El color
              // onInverseSurface contrasta con el fondo del SnackBar.
              if (icon != null) ...[
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  /// Recibe cualquier error y decide cómo mostrarlo al usuario.
  static Future<void> showError(BuildContext context, Object error) async {
    // Si la pantalla ya se cerró, no mostramos nada.
    if (!context.mounted) return;
    // AppScope.of(context) nos da los servicios de permisos y de ubicación,
    // que se usan para abrir los ajustes del teléfono.
    final deps = AppScope.of(context);

    // Pattern matching sobre la clase sellada AppException: cada case revisa el
    // tipo del error y también el valor de sus campos. El orden importa: los
    // casos más específicos van primero.
    switch (error) {
      // Permiso bloqueado para siempre: solo se puede activar desde los ajustes
      // del sistema, así que ofrecemos un diálogo con el botón 'Abrir
      // ajustes'.
      case PermissionException(permanentlyDenied: true):
        final open = await _askAction(
          context,
          icon: Icons.lock_outline,
          title: 'Permiso necesario',
          message: error.message,
          actionLabel: 'Abrir ajustes',
        );
        if (open) await deps.permissionService.openAppSettings();

      // GPS apagado: diálogo con el botón 'Activar ubicación', que abre los
      // ajustes de ubicación del teléfono.
      case ServiceDisabledException(feature: DeviceFeature.location):
        final open = await _askAction(
          context,
          icon: Icons.location_off_outlined,
          title: 'GPS desactivado',
          message: '${error.message} Actívala para guardar dónde escribiste.',
          actionLabel: 'Activar ubicación',
        );
        if (open) await deps.locationService.openLocationSettings();

      // Cualquier otro AppException (por ejemplo, un título vacío): SnackBar
      // con su mensaje en español. Se revisa mounted antes de usar el context.
      case AppException():
        if (context.mounted) {
          showMessage(context, error.message, icon: Icons.info_outline);
        }

      // Error desconocido (no es AppException): mensaje genérico, sin mostrar
      // detalles técnicos al usuario.
      default:
        if (context.mounted) {
          showMessage(
            context,
            'Ocurrió un error inesperado. Intenta de nuevo.',
          );
        }
    }
  }

  /// Diálogo de confirmación genérico. Devuelve `true` si el usuario acepta.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
    IconData? icon,
  }) async {
    // Leemos los colores del tema antes de abrir el diálogo.
    final scheme = Theme.of(context).colorScheme;
    // showDialog devuelve un Future que se completa con el valor que se pasa a
    // Navigator.pop: false al cancelar y true al confirmar.
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: icon == null ? null : Icon(icon),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          // Si la acción es destructiva (como borrar), el botón se pinta con
          // el color de error para advertir al usuario.
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    // Si el usuario cierra el diálogo tocando fuera, el resultado es null y lo
    // tratamos como false.
    return result ?? false;
  }

  /// Atajo privado para los diálogos de error: reutiliza confirm con un ícono
  /// y el texto del botón de acción.
  static Future<bool> _askAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
  }) {
    return confirm(
      context,
      icon: icon,
      title: title,
      message: message,
      confirmLabel: actionLabel,
    );
  }
}
