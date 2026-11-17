import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/settings_repository.dart';

/// Preferencias del usuario guardadas con SharedPreferences.
///
/// Usa [SharedPreferencesWithCache]: la lectura es síncrona (desde la
/// caché en memoria) y la escritura es asíncrona hacia el disco.
class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository._(this._prefs);

  static const String _biometricKey = 'biometric_lock_enabled';
  static const String _themeKey = 'theme_preference';

  final SharedPreferencesWithCache _prefs;

  static Future<SharedPrefsSettingsRepository> create() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {_biometricKey, _themeKey},
      ),
    );
    return SharedPrefsSettingsRepository._(prefs);
  }

  @override
  bool get biometricLockEnabled => _prefs.getBool(_biometricKey) ?? false;

  @override
  Future<void> setBiometricLockEnabled(bool enabled) =>
      _prefs.setBool(_biometricKey, enabled);

  @override
  ThemePreference get themePreference {
    final stored = _prefs.getString(_themeKey);
    return ThemePreference.values.firstWhere(
      (value) => value.name == stored,
      orElse: () => ThemePreference.system,
    );
  }

  @override
  Future<void> setThemePreference(ThemePreference preference) =>
      _prefs.setString(_themeKey, preference.name);
}
