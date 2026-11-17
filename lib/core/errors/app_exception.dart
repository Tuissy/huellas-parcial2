/// Recursos de hardware o del sistema que la app utiliza.
///
/// Se usa en las excepciones para construir mensajes claros al usuario.
enum DeviceFeature {
  camera('la cámara'),
  gallery('la galería'),
  microphone('el micrófono'),
  location('la ubicación'),
  biometrics('la autenticación biométrica'),
  maps('la aplicación de mapas');

  const DeviceFeature(this.label);

  final String label;
}

/// Excepción base de la aplicación.
///
/// Todas las capas convierten los errores técnicos (PlatformException,
/// DatabaseException, TimeoutException...) en una subclase de
/// [AppException] con un [message] apto para mostrarse al usuario. Así la
/// interfaz nunca depende de los detalles de cada paquete.
sealed class AppException implements Exception {
  const AppException(this.message, [this.cause]);

  /// Mensaje en español, listo para mostrar en la interfaz.
  final String message;

  /// Error original (útil para logs y depuración).
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' ($cause)' : ''}';
}

/// El usuario negó un permiso del sistema.
class PermissionException extends AppException {
  PermissionException(this.feature, {this.permanentlyDenied = false})
      : super(
          permanentlyDenied
              ? 'El permiso para usar ${feature.label} está bloqueado. '
                  'Puedes activarlo desde los ajustes del dispositivo.'
              : 'Necesitamos permiso para usar ${feature.label}.',
        );

  final DeviceFeature feature;

  /// `true` cuando el sistema ya no mostrará el diálogo de permiso y la
  /// única opción es abrir los ajustes de la app.
  final bool permanentlyDenied;
}

/// Un servicio del sistema está apagado (por ejemplo, el GPS).
class ServiceDisabledException extends AppException {
  ServiceDisabledException(this.feature)
      : super('${_capitalize(feature.label)} está desactivada en el dispositivo.');

  final DeviceFeature feature;
}

/// El hardware no existe, no responde o el servicio no está disponible.
class HardwareUnavailableException extends AppException {
  const HardwareUnavailableException(this.feature, String message, [Object? cause])
      : super(message, cause);

  final DeviceFeature feature;
}

/// El GPS no obtuvo una posición dentro del tiempo límite.
class LocationTimeoutException extends AppException {
  const LocationTimeoutException()
      : super('No se pudo obtener la ubicación a tiempo. '
            'Intenta en un lugar con mejor señal GPS.');
}

/// Error al leer o escribir en la base de datos o en el sistema de archivos.
class StorageException extends AppException {
  const StorageException(super.message, [super.cause]);
}

/// Falló la autenticación biométrica o por credencial del dispositivo.
class AuthenticationException extends AppException {
  const AuthenticationException(super.message, [super.cause]);
}

/// No fue posible abrir una aplicación externa (por ejemplo Google Maps).
class ExternalAppException extends AppException {
  const ExternalAppException(super.message, [super.cause]);
}

/// Datos de entrada inválidos detectados por las reglas de negocio.
class ValidationException extends AppException {
  const ValidationException(super.message);
}

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
