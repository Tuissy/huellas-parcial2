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

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<int>? _countFuture;
  bool _togglingLock = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _countFuture ??= AppScope.of(context).diaryRepository.count();
  }

  /// Para activar el bloqueo se exige autenticarse primero: así se
  /// comprueba que el dispositivo tiene biometría/PIN y que el usuario
  /// realmente es el dueño.
  Future<void> _toggleBiometric(bool enable) async {
    final settings = SettingsScope.of(context);
    final auth = AppScope.of(context).biometricAuthService;
    setState(() => _togglingLock = true);
    try {
      if (enable && !await auth.isAvailable()) {
        if (mounted) {
          AppFeedback.showMessage(
            context,
            'Configura una huella, rostro o PIN en el dispositivo primero.',
            icon: Icons.warning_amber,
          );
        }
        return;
      }
      final ok = await auth.authenticate(
        reason: enable
            ? 'Confirma tu identidad para activar el bloqueo'
            : 'Confirma tu identidad para desactivar el bloqueo',
      );
      if (!ok) return;
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
      if (mounted) await AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _togglingLock = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      drawer: const AppDrawer(currentRoute: AppRoutes.settings),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _Header('Seguridad'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Bloqueo biométrico'),
            subtitle: const Text('Pide huella, rostro o PIN al abrir la app'),
            value: settings.biometricLockEnabled,
            onChanged: _togglingLock ? null : _toggleBiometric,
          ),
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
              selected: {settings.themePreference},
              onSelectionChanged: (selection) =>
                  settings.setThemePreference(selection.first),
            ),
          ),
          const _Header('Permisos'),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Permisos de la app'),
            subtitle: const Text('Cámara, micrófono y ubicación'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () =>
                AppScope.of(context).permissionService.openAppSettings(),
          ),
          const _Header('Datos'),
          FutureBuilder<int>(
            future: _countFuture,
            builder: (context, snapshot) {
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

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

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
