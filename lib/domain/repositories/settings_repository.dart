/// Preferencia de tema elegida por el usuario.
enum ThemePreference { system, light, dark }

/// Contrato para las preferencias simples de la app (clave-valor).
///
/// Se implementa con SharedPreferences: los diarios van en SQLite y las
/// preferencias ligeras aquí, cada una en el almacenamiento adecuado.
abstract interface class SettingsRepository {
  bool get biometricLockEnabled;
  Future<void> setBiometricLockEnabled(bool enabled);

  ThemePreference get themePreference;
  Future<void> setThemePreference(ThemePreference preference);
}
