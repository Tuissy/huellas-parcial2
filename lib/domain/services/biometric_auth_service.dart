/// Autenticación con biometría (huella / rostro) o credencial del
/// dispositivo (PIN, patrón o contraseña) como respaldo.
abstract interface class BiometricAuthService {
  /// `true` si el dispositivo tiene algún método de autenticación
  /// configurado (biometría o bloqueo de pantalla).
  Future<bool> isAvailable();

  /// Muestra el diálogo del sistema.
  ///
  /// Devuelve `true` si el usuario se autenticó y `false` si canceló.
  /// Lanza `AuthenticationException` ante bloqueos u otros errores.
  Future<bool> authenticate({required String reason});
}
