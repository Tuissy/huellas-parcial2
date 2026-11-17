import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/services/media_service.dart';
import '../../domain/services/permission_service.dart';

/// Cámara y galería mediante el paquete image_picker.
class ImagePickerMediaService implements MediaService {
  ImagePickerMediaService(this._permissions, {ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final PermissionService _permissions;
  final ImagePicker _picker;

  // Se limita la resolución para no llenar el almacenamiento del usuario.
  static const double _maxDimension = 1920;
  static const int _quality = 85;

  @override
  Future<String?> pickPhoto(PhotoSource source) async {
    final feature = source == PhotoSource.camera
        ? DeviceFeature.camera
        : DeviceFeature.gallery;

    // La galería usa el selector de fotos del sistema (Android 13+ / iOS
    // PHPicker), que no requiere permiso. La cámara sí lo requiere.
    if (source == PhotoSource.camera) {
      final status = await _permissions.request(AppPermission.camera);
      if (status != PermissionStatusResult.granted) {
        throw PermissionException(
          DeviceFeature.camera,
          permanentlyDenied: status == PermissionStatusResult.permanentlyDenied,
        );
      }
    }

    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: _maxDimension,
        maxHeight: _maxDimension,
        imageQuality: _quality,
        requestFullMetadata: false,
      );
      return file?.path;
    } on PlatformException catch (error) {
      developer.log('Error de image_picker', error: error);
      throw _mapPlatformError(error, feature);
    }
  }

  @override
  Future<List<String>> recoverLostPhotos() async {
    if (!Platform.isAndroid) return const [];
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return const [];
      return (response.files ?? const <XFile>[]).map((f) => f.path).toList();
    } catch (error) {
      developer.log('No se pudieron recuperar fotos perdidas', error: error);
      return const [];
    }
  }

  AppException _mapPlatformError(
    PlatformException error,
    DeviceFeature feature,
  ) {
    switch (error.code) {
      case 'camera_access_denied':
      case 'photo_access_denied':
        return PermissionException(feature, permanentlyDenied: true);
      case 'no_available_camera':
        return HardwareUnavailableException(
          feature,
          'Este dispositivo no tiene una cámara disponible.',
          error,
        );
      default:
        return HardwareUnavailableException(
          feature,
          'No se pudo abrir ${feature.label}. Intenta de nuevo.',
          error,
        );
    }
  }
}
