// Capa de dominio: interfaz de permisos. Usa enums propios para que el
// dominio no dependa de los tipos del paquete permission_handler, que
// solo se usa en la capa de datos (HandlerPermissionService).
/// Permisos de tiempo de ejecución que la app solicita.
enum AppPermission { camera, microphone, speechRecognition }

/// Resultado de una solicitud de permiso.
enum PermissionStatusResult { granted, denied, permanentlyDenied }

// Las pruebas usan FakePermissionService para simular un permiso
// concedido o negado sin mostrar diálogos reales.
/// Solicitud de permisos del sistema operativo.
abstract interface class PermissionService {
  /// Solicita [permission] (si ya está concedido no muestra diálogo).
  Future<PermissionStatusResult> request(AppPermission permission);

  /// Abre la pantalla de ajustes de la aplicación.
  Future<bool> openAppSettings();
}
