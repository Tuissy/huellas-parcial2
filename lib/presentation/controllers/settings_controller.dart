// ARCHIVO: settings_controller.dart. Controlador de las preferencias de la app:
// el tema (claro, oscuro o el del sistema) y si el bloqueo con huella está
// activado. Concepto: ChangeNotifier, el controlador avisa a la interfaz cuando
// cambia el estado.
import 'package:flutter/material.dart';

import '../../domain/repositories/settings_repository.dart';

/// Estado global de las preferencias (tema y bloqueo biométrico).
///
/// `MaterialApp` escucha este controlador para cambiar de tema al vuelo.
class SettingsController extends ChangeNotifier {
  // El constructor recibe el repositorio y lee los valores guardados para
  // arrancar con el estado actual. SettingsRepository es una interfaz del
  // dominio: el controlador no sabe que por debajo se usa SharedPreferences
  // (inversión de dependencias).
  SettingsController(this._repository)
    : _themePreference = _repository.themePreference,
      _biometricLockEnabled = _repository.biometricLockEnabled;

  // Repositorio donde se guardan las preferencias.
  final SettingsRepository _repository;

  // Estado privado: solo este controlador puede cambiarlo. La interfaz lo lee
  // con los getters de abajo.
  ThemePreference _themePreference;
  bool _biometricLockEnabled;

  ThemePreference get themePreference => _themePreference;
  bool get biometricLockEnabled => _biometricLockEnabled;

  // Traduce la preferencia del dominio al ThemeMode de Flutter que entiende
  // MaterialApp. Es un switch expression con pattern matching: el compilador
  // obliga a cubrir los tres valores del enum.
  ThemeMode get themeMode => switch (_themePreference) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  /// Cambia el tema elegido por el usuario.
  Future<void> setThemePreference(ThemePreference preference) async {
    // Si es el mismo tema, no hacemos nada (evita reconstrucciones
    // innecesarias).
    if (preference == _themePreference) return;
    // Primero actualizamos el estado y llamamos a notifyListeners() para que
    // MaterialApp cambie de tema al instante. Después guardamos el valor para
    // la próxima vez que se abra la app.
    _themePreference = preference;
    notifyListeners();
    await _repository.setThemePreference(preference);
  }

  /// Activa o desactiva el bloqueo biométrico.
  Future<void> setBiometricLockEnabled(bool enabled) async {
    // Mismo patrón: comparar, actualizar, notificar y guardar. El cambio se
    // nota la próxima vez que se abre la app, porque la ruta inicial (bloqueo
    // o inicio) se decide al arrancar.
    if (enabled == _biometricLockEnabled) return;
    _biometricLockEnabled = enabled;
    notifyListeners();
    await _repository.setBiometricLockEnabled(enabled);
  }
}

/// Proporciona el [SettingsController] al árbol y reconstruye a quienes
/// dependen de él cuando cambia.
class SettingsScope extends InheritedNotifier<SettingsController> {
  // Concepto: InheritedNotifier. Es un InheritedWidget que además escucha al
  // ChangeNotifier: cuando el controlador llama a notifyListeners(), se
  // reconstruyen los widgets que usaron SettingsScope.of(context). Se coloca en
  // app.dart, por encima de MaterialApp, para que toda la app pueda acceder.
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Forma cómoda de obtener el controlador desde cualquier pantalla:
  /// SettingsScope.of(context).
  static SettingsController of(BuildContext context) {
    // dependOnInheritedWidgetOfExactType busca el SettingsScope más cercano y
    // registra la dependencia; por eso el widget que lo llama se reconstruye
    // cuando cambian los ajustes.
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    // assert solo se comprueba en modo depuración y avisa si olvidamos poner
    // SettingsScope en el árbol.
    assert(scope != null, 'No se encontró SettingsScope en el árbol.');
    return scope!.notifier!;
  }
}
