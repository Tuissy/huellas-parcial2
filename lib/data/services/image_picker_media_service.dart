import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/services/media_service.dart';
import '../../domain/services/permission_service.dart';

/// Cámara y galería mediante el paquete image_picker.
class ImagePickerMediaService implements MediaService {
  // Adaptador del plugin image_picker que implementa la interfaz
  // MediaService del dominio (inversión de dependencias). Recibe el
  // servicio de permisos por constructor en lugar de crearlo él mismo.
  ImagePickerMediaService(this._permissions, {ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final PermissionService _permissions;
  final ImagePicker _picker;

  // Se limita la resolución para no llenar el almacenamiento del usuario.
  static const double _maxDimension = 1920;
  static const int _quality = 85;

  /// Toma una foto con la cámara o la elige de la galería y devuelve su
  /// ruta temporal (o null si el usuario canceló).
  @override
  Future<String?> pickPhoto(PhotoSource source) async {
    // Se identifica el recurso (cámara o galería) para armar los mensajes
    // de error.
    final feature = source == PhotoSource.camera
        ? DeviceFeature.camera
        : DeviceFeature.gallery;

    // La galería usa el selector de fotos del sistema (Android 13+ / iOS
    // PHPicker), que no requiere permiso. La cámara sí lo requiere.
    if (source == PhotoSource.camera) {
      final status = await _permissions.request(AppPermission.camera);
      // Permiso negado vs bloqueado: si quedó bloqueado, la excepción lo
      // indica para que la pantalla ofrezca abrir los ajustes de la app.
      if (status != PermissionStatusResult.granted) {
        throw PermissionException(
          DeviceFeature.camera,
          permanentlyDenied: status == PermissionStatusResult.permanentlyDenied,
        );
      }
    }

    try {
      // Se abre la cámara o la galería. La foto se reduce a 1920 px y calidad
      // 85, y no se piden los metadatos completos de la imagen, que en iOS
      // pueden requerir un permiso extra.
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: _maxDimension,
        maxHeight: _maxDimension,
        imageQuality: _quality,
        requestFullMetadata: false,
      );
      // Si el usuario canceló, file es null y se devuelve null.
      return file?.path;
      // try-catch: el error técnico del plugin se traduce a una AppException
      // con mensaje en español.
    } on PlatformException catch (error) {
      developer.log('Error de image_picker', error: error);
      throw _mapPlatformError(error, feature);
    }
  }

  /// Recupera las fotos que se perdieron si Android cerró la app mientras
  /// la cámara estaba abierta (por ejemplo, por falta de memoria).
  @override
  Future<List<String>> recoverLostPhotos() async {
    // Este caso solo ocurre en Android; en otras plataformas no hay nada.
    if (!Platform.isAndroid) return const [];
    try {
      // retrieveLostData devuelve las fotos pendientes, si las hay.
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return const [];
      return (response.files ?? const <XFile>[]).map((f) => f.path).toList();
      // Si algo falla, se registra y se continúa sin fotos recuperadas.
    } catch (error) {
      developer.log('No se pudieron recuperar fotos perdidas', error: error);
      return const [];
    }
  }

  /// Traduce los códigos de error de image_picker a excepciones de la app.
  AppException _mapPlatformError(
    PlatformException error,
    DeviceFeature feature,
  ) {
    switch (error.code) {
      // El sistema negó el acceso: se trata como permiso bloqueado.
      case 'camera_access_denied':
      case 'photo_access_denied':
        return PermissionException(feature, permanentlyDenied: true);
      // El equipo no tiene cámara (por ejemplo, algunos emuladores).
      case 'no_available_camera':
        return HardwareUnavailableException(
          feature,
          'Este dispositivo no tiene una cámara disponible.',
          error,
        );
      // Cualquier otro error: mensaje genérico con el nombre del recurso.
      default:
        return HardwareUnavailableException(
          feature,
          'No se pudo abrir ${feature.label}. Intenta de nuevo.',
          error,
        );
    }
  }
}
