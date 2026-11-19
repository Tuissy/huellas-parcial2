// Capa de dominio: interfaz de cámara y galería. La implementa
// ImagePickerMediaService (capa de datos) con el paquete image_picker;
// las pruebas usan FakeMediaService.
// Enum propio para indicar de dónde sale la foto, sin depender del
// paquete externo.
/// Origen de una foto.
enum PhotoSource { camera, gallery }

/// Captura y selección de imágenes (cámara y galería).
abstract interface class MediaService {
  /// Abre la cámara o la galería y devuelve la ruta temporal de la imagen,
  /// o `null` si el usuario canceló.
  ///
  /// Puede lanzar `PermissionException` o `HardwareUnavailableException`.
  Future<String?> pickPhoto(PhotoSource source);

  /// En Android el sistema puede destruir la actividad mientras la cámara
  /// está abierta. Este método recupera las fotos tomadas en ese caso.
  Future<List<String>> recoverLostPhotos();
}
