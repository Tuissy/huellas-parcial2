import 'dart:developer' as developer;

import 'package:local_auth/local_auth.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/services/biometric_auth_service.dart';

/// Autenticación biométrica con el paquete local_auth.
///
/// Se permite el PIN/patrón del dispositivo como respaldo
/// (`biometricOnly: false`) para que el usuario no quede bloqueado si su
/// huella falla o el sensor no está disponible.
class LocalAuthBiometricService implements BiometricAuthService {
  // Adaptador del plugin: la capa de datos implementa la interfaz
  // BiometricAuthService del dominio (inversión de dependencias).
  // El objeto LocalAuthentication se puede inyectar para hacer pruebas.
  LocalAuthBiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Indica si el dispositivo puede autenticar al usuario.
  @override
  Future<bool> isAvailable() async {
    // isDeviceSupported es verdadero si el equipo puede verificar biometría
    // o, en su lugar, usar el bloqueo de pantalla (PIN, patrón o clave).
    // Si el plugin falla, se responde "no disponible" en vez de romper.
    try {
      return await _auth.isDeviceSupported();
    } catch (error) {
      developer.log('No se pudo consultar local_auth', error: error);
      return false;
    }
  }

  /// Muestra el diálogo del sistema para pedir huella, rostro o PIN.
  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      // local_auth con PIN de respaldo: biometricOnly en false permite usar el
      // PIN o patrón si la huella falla. Con persistAcrossBackgrounding, si el
      // sistema corta la autenticación porque la app pasó a segundo plano, el
      // plugin la vuelve a intentar al regresar.
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      // try-catch: cada código de error del plugin se traduce a una respuesta
      // (false) o a una AuthenticationException con mensaje en español.
    } on LocalAuthException catch (error) {
      developer.log('Fallo de autenticación: ${error.code}', error: error);
      switch (error.code) {
        // Si el usuario o el sistema cancelaron, se agotó el tiempo o se
        // pidió otra opción, no es un error grave: solo se devuelve false.
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
        case LocalAuthExceptionCode.userRequestedFallback:
          return false;
        // El dispositivo no tiene huella, rostro ni bloqueo de pantalla.
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          throw AuthenticationException(
            'Configura una huella, rostro o bloqueo de pantalla en el dispositivo.',
            error,
          );
        // Bloqueo temporal por demasiados intentos fallidos.
        case LocalAuthExceptionCode.temporaryLockout:
          throw AuthenticationException(
            'Demasiados intentos. Espera unos segundos e inténtalo de nuevo.',
            error,
          );
        // Biometría bloqueada: hay que desbloquear el equipo con el PIN.
        case LocalAuthExceptionCode.biometricLockout:
          throw AuthenticationException(
            'La biometría está bloqueada. Desbloquea el dispositivo con tu PIN.',
            error,
          );
        // No hay sensor o el sensor no está disponible por ahora.
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          throw AuthenticationException(
            'El sensor biométrico no está disponible en este momento.',
            error,
          );
        // Cualquier otro código recibe un mensaje genérico.
        default:
          throw AuthenticationException(
            'No se pudo completar la autenticación.',
            error,
          );
      }
      // Error inesperado que no viene del plugin: también se traduce.
    } catch (error) {
      developer.log('Error inesperado de local_auth', error: error);
      throw AuthenticationException(
        'No se pudo completar la autenticación.',
        error,
      );
    }
  }
}
