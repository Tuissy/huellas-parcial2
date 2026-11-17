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
  static void showMessage(
    BuildContext context,
    String message, {
    IconData? icon,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
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

  static Future<void> showError(BuildContext context, Object error) async {
    if (!context.mounted) return;
    final deps = AppScope.of(context);

    switch (error) {
      case PermissionException(permanentlyDenied: true):
        final open = await _askAction(
          context,
          icon: Icons.lock_outline,
          title: 'Permiso necesario',
          message: error.message,
          actionLabel: 'Abrir ajustes',
        );
        if (open) await deps.permissionService.openAppSettings();

      case ServiceDisabledException(feature: DeviceFeature.location):
        final open = await _askAction(
          context,
          icon: Icons.location_off_outlined,
          title: 'GPS desactivado',
          message: '${error.message} Actívala para guardar dónde escribiste.',
          actionLabel: 'Activar ubicación',
        );
        if (open) await deps.locationService.openLocationSettings();

      case AppException():
        if (context.mounted) {
          showMessage(context, error.message, icon: Icons.info_outline);
        }

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
    final scheme = Theme.of(context).colorScheme;
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
    return result ?? false;
  }

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
