import 'dart:io';

import 'package:permission_handler/permission_handler.dart' as ph;

import '../../domain/services/permission_service.dart';

/// Implementación de [PermissionService] con el paquete permission_handler.
class HandlerPermissionService implements PermissionService {
  const HandlerPermissionService();

  @override
  Future<PermissionStatusResult> request(AppPermission permission) async {
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

    var status = await target.status;
    if (!status.isGranted && !status.isLimited) {
      status = await target.request();
    }
    if (status.isGranted || status.isLimited) {
      return PermissionStatusResult.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionStatusResult.permanentlyDenied;
    }
    return PermissionStatusResult.denied;
  }

  @override
  Future<bool> openAppSettings() => ph.openAppSettings();
}
