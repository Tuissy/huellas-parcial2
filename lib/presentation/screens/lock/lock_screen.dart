import 'package:flutter/material.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/errors/app_exception.dart';
import '../../controllers/settings_controller.dart';
import '../../routes/app_routes.dart';

/// Pantalla de inicio de sesión biométrico.
///
/// Se muestra al abrir la app cuando el usuario activó el bloqueo en
/// Ajustes. Solo tras autenticarse se reemplaza por la lista de diarios
/// (`pushReplacementNamed`), de modo que no hay forma de volver "atrás" a
/// contenido protegido.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _authenticating = false;
  String? _message;
  bool _deviceWithoutLock = false;

  @override
  void initState() {
    super.initState();
    // Lanza el diálogo del sistema automáticamente al abrir la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    final auth = AppScope.of(context).biometricAuthService;
    setState(() {
      _authenticating = true;
      _message = null;
    });

    try {
      if (!await auth.isAvailable()) {
        // El usuario quitó el bloqueo del dispositivo después de activar
        // la protección: no hay con qué autenticar.
        setState(() {
          _deviceWithoutLock = true;
          _message =
              'Tu dispositivo ya no tiene huella ni bloqueo de pantalla. '
              'Configúralo para proteger tus diarios.';
        });
        return;
      }
      final success = await auth.authenticate(
        reason: 'Desbloquea Huellas para ver tus diarios',
      );
      if (!mounted) return;
      if (success) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        setState(() => _message = 'Autenticación cancelada.');
      }
    } on AuthenticationException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  /// Si el dispositivo ya no tiene ningún método de bloqueo, se desactiva
  /// la protección para no dejar al usuario fuera de sus propios datos.
  Future<void> _continueWithoutLock() async {
    await SettingsScope.of(context).setBiometricLockEnabled(false);
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.primaryContainer, scheme.surface],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: scheme.primary,
                      child: Icon(
                        Icons.fingerprint,
                        size: 64,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Huellas está protegido',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Usa tu huella, rostro o PIN para abrir tu diario.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _message == null
                        ? const SizedBox(height: 24)
                        : Text(
                            _message!,
                            key: ValueKey(_message),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  if (_deviceWithoutLock)
                    FilledButton.icon(
                      onPressed: _continueWithoutLock,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Continuar sin bloqueo'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _authenticating ? null : _unlock,
                      icon: _authenticating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open),
                      label: const Text('Desbloquear'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
