/// Almacenamiento permanente de las fotos del diario.
///
/// Las imágenes que entrega la cámara o la galería viven en carpetas
/// temporales que el sistema puede borrar. Este servicio las copia al
/// directorio privado de la app para que sobrevivan a reinicios.
abstract interface class ImageStorageService {
  /// Copia la imagen de [sourcePath] al almacenamiento permanente y devuelve
  /// la nueva ruta absoluta. Si ya es permanente, devuelve la misma ruta.
  Future<String> persist(String sourcePath);

  /// Borra la imagen (ignora rutas que no existan).
  Future<void> delete(String path);

  /// Convierte una ruta absoluta en la ruta relativa que se guarda en la
  /// base de datos. En iOS el directorio del contenedor cambia entre
  /// actualizaciones, por eso nunca se guardan rutas absolutas.
  String toStoredPath(String absolutePath);

  /// Operación inversa de [toStoredPath].
  String toAbsolutePath(String storedPath);
}
