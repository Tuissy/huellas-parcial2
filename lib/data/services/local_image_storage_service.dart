import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/services/image_storage_service.dart';

/// Guarda las fotos del diario en `<documentos de la app>/diary_images`.
class LocalImageStorageService implements ImageStorageService {
  // Implementa la interfaz ImageStorageService del dominio (inversión de
  // dependencias). Responsabilidad única: manejar los archivos de fotos.
  LocalImageStorageService(this._documentsPath);

  // Nombre de la carpeta donde se guardan las fotos.
  static const String _folderName = 'diary_images';

  /// Directorio de documentos de la app (privado y persistente).
  final String _documentsPath;
  // Generador aleatorio para que dos fotos nunca tengan el mismo nombre.
  final Random _random = Random();

  /// Ruta completa de la carpeta de fotos.
  String get _imagesPath => p.join(_documentsPath, _folderName);

  /// Crea el servicio resolviendo el directorio de documentos una sola vez.
  static Future<LocalImageStorageService> create() async {
    final directory = await getApplicationDocumentsDirectory();
    return LocalImageStorageService(directory.path);
  }

  /// Copiar la foto a una carpeta permanente: la cámara y la galería dejan
  /// la imagen en una carpeta temporal que el sistema puede borrar.
  @override
  Future<String> persist(String sourcePath) async {
    // Ya está en el almacenamiento permanente (foto de una entrada editada).
    if (p.isWithin(_imagesPath, sourcePath)) return sourcePath;

    try {
      // Si el archivo de origen ya no existe, se avisa al usuario.
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw const StorageException(
          'Una de las fotos ya no está disponible. Vuelve a seleccionarla.',
        );
      }
      // Se crea la carpeta de fotos si todavía no existe.
      final folder = Directory(_imagesPath);
      if (!await folder.exists()) await folder.create(recursive: true);

      // Nombre único: fecha en milisegundos más un número aleatorio,
      // conservando la extensión original (o .jpg si no tiene).
      final extension = p.extension(sourcePath).isEmpty
          ? '.jpg'
          : p.extension(sourcePath).toLowerCase();
      final fileName =
          'img_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1 << 32)}$extension';
      // Se copia el archivo y se devuelve la ruta de la copia.
      final copy = await source.copy(p.join(_imagesPath, fileName));
      return copy.path;
      // Las excepciones propias se dejan pasar tal cual; los errores del
      // sistema de archivos se traducen a StorageException en español.
    } on AppException {
      rethrow;
    } on FileSystemException catch (error) {
      developer.log('No se pudo copiar la imagen', error: error);
      throw StorageException(
        'No se pudo guardar la foto. Revisa el espacio disponible.',
        error,
      );
    }
  }

  /// Borra una foto del disco si existe.
  @override
  Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      // Borrar es "mejor esfuerzo": un archivo huérfano no debe impedir
      // que el usuario elimine o edite su entrada.
      developer.log('No se pudo borrar $path', error: error);
    }
  }

  /// Rutas relativas porque en iOS la ruta del contenedor de la app puede
  /// cambiar al actualizarla: se guarda solo la parte que sigue a la
  /// carpeta de documentos (por ejemplo "diary_images/img_123.jpg").
  @override
  String toStoredPath(String absolutePath) {
    if (p.isWithin(_documentsPath, absolutePath)) {
      return p.relative(absolutePath, from: _documentsPath);
    }
    // Si la ruta está fuera de la carpeta de documentos, se deja igual.
    return absolutePath;
  }

  /// Operación inversa: une la carpeta de documentos actual con la ruta
  /// relativa guardada. Si la ruta ya es absoluta, se devuelve igual.
  @override
  String toAbsolutePath(String storedPath) {
    if (p.isAbsolute(storedPath)) return storedPath;
    return p.join(_documentsPath, storedPath);
  }
}
