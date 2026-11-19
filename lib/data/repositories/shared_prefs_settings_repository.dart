import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/settings_repository.dart';

/// Preferencias del usuario guardadas con SharedPreferences.
///
/// Usa [SharedPreferencesWithCache]: la lectura es síncrona (desde la
/// caché en memoria) y la escritura es asíncrona hacia el disco.
class SharedPrefsSettingsRepository implements SettingsRepository {
  // Implementa la interfaz SettingsRepository del dominio (inversión de
  // dependencias): la app depende del contrato, no de SharedPreferences.
  // SharedPreferences para ajustes simples clave-valor; los diarios, que
  // son datos más complejos, van en SQLite.
  // El constructor es privado: el objeto se crea con create().
  SharedPrefsSettingsRepository._(this._prefs);

  // Claves con las que se guardan los dos ajustes en el dispositivo.
  static const String _biometricKey = 'biometric_lock_enabled';
  static const String _themeKey = 'theme_preference';

  final SharedPreferencesWithCache _prefs;

  /// Crea el repositorio de forma asíncrona, porque cargar las preferencias
  /// desde el disco a la caché toma un momento.
  static Future<SharedPrefsSettingsRepository> create() async {
    // allowList: solo se cargan y se permiten estas dos claves.
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {_biometricKey, _themeKey},
      ),
    );
    return SharedPrefsSettingsRepository._(prefs);
  }

  /// Indica si el bloqueo con huella está activado (falso por defecto).
  @override
  bool get biometricLockEnabled => _prefs.getBool(_biometricKey) ?? false;

  /// Guarda si el usuario activó o desactivó el bloqueo biométrico.
  @override
  Future<void> setBiometricLockEnabled(bool enabled) =>
      _prefs.setBool(_biometricKey, enabled);

  /// Lee el tema guardado. Se guarda el nombre del enum como texto y aquí
  /// se busca el valor que coincide; si no hay ninguno, se usa "system".
  @override
  ThemePreference get themePreference {
    final stored = _prefs.getString(_themeKey);
    return ThemePreference.values.firstWhere(
      (value) => value.name == stored,
      orElse: () => ThemePreference.system,
    );
  }

  /// Guarda el tema elegido como texto (el nombre del enum).
  @override
  Future<void> setThemePreference(ThemePreference preference) =>
      _prefs.setString(_themeKey, preference.name);
}
