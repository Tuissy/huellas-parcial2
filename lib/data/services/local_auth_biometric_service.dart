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
  LocalAuthBiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (error) {
      developer.log('No se pudo consultar local_auth', error: error);
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (error) {
      developer.log('Fallo de autenticación: ${error.code}', error: error);
      switch (error.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
        case LocalAuthExceptionCode.userRequestedFallback:
          return false;
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          throw AuthenticationException(
            'Configura una huella, rostro o bloqueo de pantalla en el dispositivo.',
            error,
          );
        case LocalAuthExceptionCode.temporaryLockout:
          throw AuthenticationException(
            'Demasiados intentos. Espera unos segundos e inténtalo de nuevo.',
            error,
          );
        case LocalAuthExceptionCode.biometricLockout:
          throw AuthenticationException(
            'La biometría está bloqueada. Desbloquea el dispositivo con tu PIN.',
            error,
          );
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          throw AuthenticationException(
            'El sensor biométrico no está disponible en este momento.',
            error,
          );
        default:
          throw AuthenticationException(
            'No se pudo completar la autenticación.',
            error,
          );
      }
    } catch (error) {
      developer.log('Error inesperado de local_auth', error: error);
      throw AuthenticationException('No se pudo completar la autenticación.', error);
    }
  }
}
