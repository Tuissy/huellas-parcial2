import 'dart:io';

import 'package:permission_handler/permission_handler.dart' as ph;

import '../../domain/services/permission_service.dart';

/// Implementación de [PermissionService] con el paquete permission_handler.
class HandlerPermissionService implements PermissionService {
  // Adaptador del plugin: implementa la interfaz PermissionService del
  // dominio. Así los demás servicios piden permisos sin conocer el paquete
  // permission_handler (inversión de dependencias).
  const HandlerPermissionService();

  /// Pide un permiso al usuario y devuelve si quedó concedido, negado o
  /// bloqueado.
  @override
  Future<PermissionStatusResult> request(AppPermission permission) async {
    // Se traduce el permiso del dominio al permiso del paquete.
    final target = switch (permission) {
      AppPermission.camera => ph.Permission.camera,
      AppPermission.microphone => ph.Permission.microphone,
      AppPermission.speechRecognition => ph.Permission.speech,
    };

    // En Android el reconocimiento de voz solo requiere RECORD_AUDIO
    // (ya cubierto por el permiso de micrófono).
    if (permission == AppPermission.speechRecognition && !Platform.isIOS) {
      return PermissionStatusResult.granted;
    }

    // Si el permiso aún no está concedido, se muestra el diálogo del
    // sistema. "limited" (acceso parcial) también cuenta como concedido.
    var status = await target.status;
    if (!status.isGranted && !status.isLimited) {
      status = await target.request();
    }
    // Concedido, total o limitado.
    if (status.isGranted || status.isLimited) {
      return PermissionStatusResult.granted;
    }
    // Permiso negado vs bloqueado: bloqueado significa que el sistema ya no
    // mostrará el diálogo y hay que abrir los ajustes. "restricted" (por
    // ejemplo, control parental) se trata igual.
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionStatusResult.permanentlyDenied;
    }
    // Negado solo esta vez: se puede volver a preguntar más adelante.
    return PermissionStatusResult.denied;
  }

  /// Abre los ajustes de la app para activar un permiso bloqueado.
  @override
  Future<bool> openAppSettings() => ph.openAppSettings();
}
