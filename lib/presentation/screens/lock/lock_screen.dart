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

  // Crea el objeto State, que guarda lo que cambia en esta pantalla.
  @override
  State<LockScreen> createState() => _LockScreenState();
}

/// Estado de la pantalla de bloqueo.
class _LockScreenState extends State<LockScreen> {
  // true mientras el diálogo de autenticación está abierto; evita
  // lanzarlo dos veces y desactiva el botón.
  bool _authenticating = false;
  // Mensaje de error o aviso bajo el texto; null si no hay nada que decir.
  String? _message;
  // true si el dispositivo ya no tiene ningún bloqueo configurado.
  bool _deviceWithoutLock = false;

  // Se ejecuta una sola vez, al crear la pantalla.
  @override
  void initState() {
    super.initState();
    // Lanza el diálogo del sistema automáticamente al abrir la pantalla.
    // addPostFrameCallback espera a que se dibuje el primer cuadro.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  /// Pide la autenticación con local_auth: huella, rostro o PIN.
  Future<void> _unlock() async {
    // Si ya hay un intento en curso, no se lanza otro.
    if (_authenticating) return;
    final auth = AppScope.of(context).biometricAuthService;
    // Marca que estamos autenticando y borra el mensaje anterior.
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
      // Muestra el diálogo del sistema con el motivo del desbloqueo.
      final success = await auth.authenticate(
        reason: 'Desbloquea Huellas para ver tus diarios',
      );
      // Si la pantalla se cerró mientras esperábamos, no se hace nada.
      if (!mounted) return;
      // Éxito: pushReplacementNamed cambia el bloqueo por la lista de
      // diarios. El bloqueo sale de la pila, así que con Atrás no se
      // vuelve a él; y como debajo no había otra ruta, tampoco se puede
      // saltar el bloqueo con Atrás. Si se cancela, se avisa.
      if (success) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        setState(() => _message = 'Autenticación cancelada.');
      }
    } on AuthenticationException catch (error) {
      // Fallos como demasiados intentos: se muestra el mensaje del error.
      if (mounted) setState(() => _message = error.message);
    } finally {
      // Al terminar, en cualquier caso, se habilita de nuevo el botón.
      if (mounted) setState(() => _authenticating = false);
    }
  }

  /// Si el dispositivo ya no tiene ningún método de bloqueo, se desactiva
  /// la protección para no dejar al usuario fuera de sus propios datos.
  Future<void> _continueWithoutLock() async {
    // Apaga el bloqueo (se guarda en SharedPreferences) y entra a la
    // lista reemplazando esta pantalla.
    await SettingsScope.of(context).setBiometricLockEnabled(false);
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  // Diseño de la pantalla: ícono animado, textos, mensaje y botón.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Pantalla sin AppBar: solo el contenido de desbloqueo.
    return Scaffold(
      // Fondo con un degradado vertical de los colores del tema.
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.primaryContainer, scheme.surface],
          ),
        ),
        // SafeArea y Center: contenido centrado y lejos de las barras
        // del sistema.
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícono de huella que aparece con un pequeño rebote:
                  // TweenAnimationBuilder escala de 0.6 a 1 con una
                  // curva elástica.
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
                  // Título y explicación de qué debe hacer el usuario.
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
                  // Mensaje de error, en el color de error del tema. Con
                  // AnimatedSwitcher aparece y cambia con una transición
                  // suave (la ValueKey avisa que el texto cambió). Sin
                  // mensaje queda un espacio fijo para que nada salte.
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
                  // Si el dispositivo ya no tiene bloqueo, se ofrece
                  // continuar sin él para no dejar al usuario afuera.
                  if (_deviceWithoutLock)
                    FilledButton.icon(
                      onPressed: _continueWithoutLock,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Continuar sin bloqueo'),
                    )
                  else
                    // Botón Desbloquear para reintentar. Mientras se
                    // autentica queda deshabilitado y muestra un
                    // CircularProgressIndicator pequeño en vez del ícono.
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
