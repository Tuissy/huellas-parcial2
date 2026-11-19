// Manejo de errores de la app (capa core). Aquí se define una
// jerarquía sellada de errores propios, con mensajes en español para
// el usuario.
/// Recursos de hardware o del sistema que la app utiliza.
///
/// Se usa en las excepciones para construir mensajes claros al usuario.
enum DeviceFeature {
  // Cada valor guarda una etiqueta en español con su artículo, para
  // armar frases como "Necesitamos permiso para usar la cámara".
  camera('la cámara'),
  gallery('la galería'),
  microphone('el micrófono'),
  location('la ubicación'),
  biometrics('la autenticación biométrica'),
  maps('la aplicación de mapas');

  // Enum mejorado: cada valor recibe su etiqueta por este constructor.
  const DeviceFeature(this.label);

  final String label;
}

// "sealed" crea una jerarquía sellada: todas las subclases deben
// estar en este archivo. Así el compilador conoce la lista completa
// de errores y un switch puede verificar que se cubran todos.
/// Excepción base de la aplicación.
///
/// Todas las capas convierten los errores técnicos (PlatformException,
/// DatabaseException, TimeoutException...) en una subclase de
/// [AppException] con un [message] apto para mostrarse al usuario. Así la
/// interfaz nunca depende de los detalles de cada paquete.
sealed class AppException implements Exception {
  // El mensaje es obligatorio y la causa es opcional (parámetro
  // posicional entre corchetes).
  const AppException(this.message, [this.cause]);

  /// Mensaje en español, listo para mostrar en la interfaz.
  final String message;

  /// Error original (útil para logs y depuración).
  final Object? cause;

  // toString pensado para los logs: tipo de error, mensaje y, si
  // existe, la causa original.
  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' ($cause)' : ''}';
}

/// El usuario negó un permiso del sistema.
class PermissionException extends AppException {
  // El mensaje cambia según el caso: si el permiso quedó bloqueado se
  // indica ir a los ajustes; si no, solo se pide el permiso.
  PermissionException(this.feature, {this.permanentlyDenied = false})
    : super(
        permanentlyDenied
            ? 'El permiso para usar ${feature.label} está bloqueado. '
                  'Puedes activarlo desde los ajustes del dispositivo.'
            : 'Necesitamos permiso para usar ${feature.label}.',
      );

  /// Recurso cuyo permiso fue negado.
  final DeviceFeature feature;

  /// `true` cuando el sistema ya no mostrará el diálogo de permiso y la
  /// única opción es abrir los ajustes de la app.
  final bool permanentlyDenied;
}

/// Un servicio del sistema está apagado (por ejemplo, el GPS).
class ServiceDisabledException extends AppException {
  // Arma un mensaje como "La ubicación está desactivada en el
  // dispositivo", usando _capitalize para la primera mayúscula.
  ServiceDisabledException(this.feature)
    : super(
        '${_capitalize(feature.label)} está desactivada en el dispositivo.',
      );

  /// Servicio del sistema que está apagado.
  final DeviceFeature feature;
}

/// El hardware no existe, no responde o el servicio no está disponible.
class HardwareUnavailableException extends AppException {
  // Aquí el mensaje lo escribe quien lanza el error, porque cada fallo
  // de hardware es distinto; también puede guardar la causa original.
  const HardwareUnavailableException(
    this.feature,
    String message, [
    Object? cause,
  ]) : super(message, cause);

  /// Recurso de hardware que falló.
  final DeviceFeature feature;
}

/// El GPS no obtuvo una posición dentro del tiempo límite.
class LocationTimeoutException extends AppException {
  // No recibe datos: el mensaje siempre es el mismo.
  const LocationTimeoutException()
    : super(
        'No se pudo obtener la ubicación a tiempo. '
        'Intenta en un lugar con mejor señal GPS.',
      );
}

/// Error al leer o escribir en la base de datos o en el sistema de archivos.
class StorageException extends AppException {
  // Usa parámetros super (super.message) para pasar el mensaje y la
  // causa directo a la clase base sin repetir código.
  const StorageException(super.message, [super.cause]);
}

/// Falló la autenticación biométrica o por credencial del dispositivo.
class AuthenticationException extends AppException {
  // Mensaje y causa original se pasan directo a la clase base.
  const AuthenticationException(super.message, [super.cause]);
}

/// No fue posible abrir una aplicación externa (por ejemplo Google Maps).
class ExternalAppException extends AppException {
  // Mensaje y causa original se pasan directo a la clase base.
  const ExternalAppException(super.message, [super.cause]);
}

/// Datos de entrada inválidos detectados por las reglas de negocio.
class ValidationException extends AppException {
  // Solo lleva mensaje: es un error de reglas de negocio, no técnico.
  const ValidationException(super.message);
}

/// Función privada (empieza con guion bajo): pone en mayúscula la
/// primera letra de un texto; si está vacío, lo devuelve igual.
String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
