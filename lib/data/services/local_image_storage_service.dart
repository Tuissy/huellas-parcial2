import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/services/image_storage_service.dart';

/// Guarda las fotos del diario en `<documentos de la app>/diary_images`.
class LocalImageStorageService implements ImageStorageService {
  LocalImageStorageService(this._documentsPath);

  static const String _folderName = 'diary_images';

  /// Directorio de documentos de la app (privado y persistente).
  final String _documentsPath;
  final Random _random = Random();

  String get _imagesPath => p.join(_documentsPath, _folderName);

  /// Crea el servicio resolviendo el directorio de documentos una sola vez.
  static Future<LocalImageStorageService> create() async {
    final directory = await getApplicationDocumentsDirectory();
    return LocalImageStorageService(directory.path);
  }

  @override
  Future<String> persist(String sourcePath) async {
    // Ya está en el almacenamiento permanente (foto de una entrada editada).
    if (p.isWithin(_imagesPath, sourcePath)) return sourcePath;

    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw const StorageException(
          'Una de las fotos ya no está disponible. Vuelve a seleccionarla.',
        );
      }
      final folder = Directory(_imagesPath);
      if (!await folder.exists()) await folder.create(recursive: true);

      final extension = p.extension(sourcePath).isEmpty
          ? '.jpg'
          : p.extension(sourcePath).toLowerCase();
      final fileName =
          'img_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1 << 32)}$extension';
      final copy = await source.copy(p.join(_imagesPath, fileName));
      return copy.path;
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

  @override
  String toStoredPath(String absolutePath) {
    if (p.isWithin(_documentsPath, absolutePath)) {
      return p.relative(absolutePath, from: _documentsPath);
    }
    return absolutePath;
  }

  @override
  String toAbsolutePath(String storedPath) {
    if (p.isAbsolute(storedPath)) return storedPath;
    return p.join(_documentsPath, storedPath);
  }
}
