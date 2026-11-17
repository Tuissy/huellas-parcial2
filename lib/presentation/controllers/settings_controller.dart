import 'package:flutter/material.dart';

import '../../domain/repositories/settings_repository.dart';

/// Estado global de las preferencias (tema y bloqueo biométrico).
///
/// `MaterialApp` escucha este controlador para cambiar de tema al vuelo.
class SettingsController extends ChangeNotifier {
  SettingsController(this._repository)
    : _themePreference = _repository.themePreference,
      _biometricLockEnabled = _repository.biometricLockEnabled;

  final SettingsRepository _repository;

  ThemePreference _themePreference;
  bool _biometricLockEnabled;

  ThemePreference get themePreference => _themePreference;
  bool get biometricLockEnabled => _biometricLockEnabled;

  ThemeMode get themeMode => switch (_themePreference) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  Future<void> setThemePreference(ThemePreference preference) async {
    if (preference == _themePreference) return;
    _themePreference = preference;
    notifyListeners();
    await _repository.setThemePreference(preference);
  }

  Future<void> setBiometricLockEnabled(bool enabled) async {
    if (enabled == _biometricLockEnabled) return;
    _biometricLockEnabled = enabled;
    notifyListeners();
    await _repository.setBiometricLockEnabled(enabled);
  }
}

/// Proporciona el [SettingsController] al árbol y reconstruye a quienes
/// dependen de él cuando cambia.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No se encontró SettingsScope en el árbol.');
    return scope!.notifier!;
  }
}
