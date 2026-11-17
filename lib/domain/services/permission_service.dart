/// Permisos de tiempo de ejecución que la app solicita.
enum AppPermission { camera, microphone, speechRecognition }

/// Resultado de una solicitud de permiso.
enum PermissionStatusResult { granted, denied, permanentlyDenied }

/// Solicitud de permisos del sistema operativo.
abstract interface class PermissionService {
  /// Solicita [permission] (si ya está concedido no muestra diálogo).
  Future<PermissionStatusResult> request(AppPermission permission);

  /// Abre la pantalla de ajustes de la aplicación.
  Future<bool> openAppSettings();
}
