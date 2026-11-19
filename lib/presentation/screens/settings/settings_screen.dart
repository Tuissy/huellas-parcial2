import 'package:flutter/material.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../controllers/settings_controller.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_feedback.dart';

/// Ajustes: bloqueo biométrico, tema y acceso a los permisos del sistema.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  // Crea el objeto State, que guarda lo que cambia en esta pantalla.
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// Estado de la pantalla de Ajustes.
class _SettingsScreenState extends State<SettingsScreen> {
  // Future con la cantidad de entradas guardadas en SQLite.
  Future<int>? _countFuture;
  // true mientras se cambia el bloqueo; sirve para desactivar el
  // interruptor y evitar dos toques seguidos.
  bool _togglingLock = false;

  // Pide una sola vez (gracias a ??=) cuántas entradas hay guardadas.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _countFuture ??= AppScope.of(context).diaryRepository.count();
  }

  /// Para activar el bloqueo se exige autenticarse primero: así se
  /// comprueba que el dispositivo tiene biometría/PIN y que el usuario
  /// realmente es el dueño.
  Future<void> _toggleBiometric(bool enable) async {
    // Controlador de ajustes (se guardan con SharedPreferences) y
    // servicio de autenticación (local_auth: huella, rostro o PIN).
    final settings = SettingsScope.of(context);
    final auth = AppScope.of(context).biometricAuthService;
    // Desactiva el interruptor mientras dura el proceso.
    setState(() => _togglingLock = true);
    try {
      // Si se quiere activar pero el dispositivo no puede autenticar
      // (no tiene huella, rostro ni PIN), se avisa y no se activa nada.
      if (enable && !await auth.isAvailable()) {
        // mounted: comprueba que la pantalla siga abierta tras esperar.
        if (mounted) {
          AppFeedback.showMessage(
            context,
            'Configura una huella, rostro o PIN en el dispositivo primero.',
            icon: Icons.warning_amber,
          );
        }
        return;
      }
      // Muestra el diálogo del sistema con un motivo según la acción.
      final ok = await auth.authenticate(
        reason: enable
            ? 'Confirma tu identidad para activar el bloqueo'
            : 'Confirma tu identidad para desactivar el bloqueo',
      );
      // Si el usuario cancela, no se cambia nada.
      if (!ok) return;
      // Guarda la preferencia y confirma con un SnackBar.
      await settings.setBiometricLockEnabled(enable);
      if (mounted) {
        AppFeedback.showMessage(
          context,
          enable
              ? 'Bloqueo biométrico activado'
              : 'Bloqueo biométrico desactivado',
          icon: enable ? Icons.lock : Icons.lock_open,
        );
      }
    } on AppException catch (error) {
      // Errores conocidos (por ejemplo, demasiados intentos) se muestran
      // al usuario con AppFeedback, sin que la app se cierre.
      if (mounted) await AppFeedback.showError(context, error);
    } finally {
      // Pase lo que pase, se vuelve a habilitar el interruptor.
      if (mounted) setState(() => _togglingLock = false);
    }
  }

  // Lista de ajustes agrupada en secciones: Seguridad, Apariencia,
  // Permisos y Datos.
  @override
  Widget build(BuildContext context) {
    // SettingsScope: al cambiar un ajuste esta pantalla se reconstruye
    // sola con el valor nuevo.
    final settings = SettingsScope.of(context);
    final theme = Theme.of(context);

    // Scaffold con AppBar y el Drawer compartido.
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      drawer: const AppDrawer(currentRoute: AppRoutes.settings),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Sección Seguridad: interruptor del bloqueo biométrico. Su
          // valor viene de SharedPreferences; si onChanged es null, el
          // interruptor queda deshabilitado mientras se autentica.
          const _Header('Seguridad'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Bloqueo biométrico'),
            subtitle: const Text('Pide huella, rostro o PIN al abrir la app'),
            value: settings.biometricLockEnabled,
            onChanged: _togglingLock ? null : _toggleBiometric,
          ),
          // Sección Apariencia: selector de tema Sistema, Claro u Oscuro.
          // Al elegir uno, el controlador lo guarda en SharedPreferences
          // y la app cambia de tema al instante.
          const _Header('Apariencia'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemePreference>(
              segments: const [
                ButtonSegment(
                  value: ThemePreference.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('Sistema'),
                ),
                ButtonSegment(
                  value: ThemePreference.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Claro'),
                ),
                ButtonSegment(
                  value: ThemePreference.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Oscuro'),
                ),
              ],
              // Opción marcada: la preferencia guardada actualmente.
              selected: {settings.themePreference},
              onSelectionChanged: (selection) =>
                  settings.setThemePreference(selection.first),
            ),
          ),
          // Sección Permisos: abre la configuración de la app en el
          // sistema para revisar cámara, micrófono y ubicación.
          const _Header('Permisos'),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Permisos de la app'),
            subtitle: const Text('Cámara, micrófono y ubicación'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () =>
                AppScope.of(context).permissionService.openAppSettings(),
          ),
          // Sección Datos: cuántas entradas hay guardadas en SQLite.
          const _Header('Datos'),
          FutureBuilder<int>(
            future: _countFuture,
            builder: (context, snapshot) {
              // switch con patrones de Dart 3 para elegir el texto según
              // el estado: error, con el dato o todavía calculando.
              final subtitle = switch (snapshot) {
                AsyncSnapshot(hasError: true) => 'No se pudo calcular',
                AsyncSnapshot(:final data?) =>
                  '$data ${data == 1 ? 'entrada' : 'entradas'} en SQLite',
                _ => 'Calculando…',
              };
              return ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Diarios guardados'),
                subtitle: Text(subtitle),
              );
            },
          ),
          // Nota de privacidad: todo se guarda solo en el dispositivo.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Tus diarios, fotos y ubicaciones se guardan solo en este dispositivo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Título de cada sección de Ajustes, pintado con el color principal
/// del tema.
class _Header extends StatelessWidget {
  const _Header(this.text);

  // Texto del título de la sección.
  final String text;

  // Dibuja el título con margen y estilo de etiqueta.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
