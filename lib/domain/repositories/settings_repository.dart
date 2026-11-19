// Capa de dominio: contrato para las preferencias del usuario.
// Enum con las tres opciones de tema: seguir al sistema, claro u
// oscuro.
/// Preferencia de tema elegida por el usuario.
enum ThemePreference { system, light, dark }

// Las pantallas dependen de esta interfaz; la capa de datos la
// implementa con SharedPreferences (SharedPrefsSettingsRepository) y
// las pruebas usan FakeSettingsRepository, que guarda todo en memoria.
/// Contrato para las preferencias simples de la app (clave-valor).
///
/// Se implementa con SharedPreferences: los diarios van en SQLite y las
/// preferencias ligeras aquí, cada una en el almacenamiento adecuado.
abstract interface class SettingsRepository {
  // Bloqueo biométrico: el getter es síncrono porque las preferencias
  // ya se cargaron en memoria al iniciar; el setter guarda el valor y
  // devuelve un Future.
  bool get biometricLockEnabled;
  Future<void> setBiometricLockEnabled(bool enabled);

  // Tema de la app: mismo esquema, lectura síncrona y guardado
  // asíncrono.
  ThemePreference get themePreference;
  Future<void> setThemePreference(ThemePreference preference);
}
