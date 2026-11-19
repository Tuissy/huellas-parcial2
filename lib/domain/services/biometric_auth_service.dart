// Capa de dominio: interfaz del bloqueo biométrico. La capa de datos
// la implementa con el paquete local_auth (LocalAuthBiometricService)
// y las pruebas usan FakeBiometricService, que siempre responde que
// sí.
/// Autenticación con biometría (huella / rostro) o credencial del
/// dispositivo (PIN, patrón o contraseña) como respaldo.
abstract interface class BiometricAuthService {
  // Se consulta en la pantalla de bloqueo y en los ajustes antes de
  // pedir la autenticación.
  /// `true` si el dispositivo tiene algún método de autenticación
  /// configurado (biometría o bloqueo de pantalla).
  Future<bool> isAvailable();

  // Devuelve un Future porque hay que esperar a que el usuario responda
  // en el diálogo del sistema.
  /// Muestra el diálogo del sistema.
  ///
  /// Devuelve `true` si el usuario se autenticó y `false` si canceló.
  /// Lanza `AuthenticationException` ante bloqueos u otros errores.
  Future<bool> authenticate({required String reason});
}
