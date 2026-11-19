// Capa de dominio. Caso de uso: encapsula una acción concreta del
// usuario (eliminar una entrada) y solo depende de interfaces.
import '../entities/diary_entry.dart';
import '../repositories/diary_repository.dart';
import '../services/image_storage_service.dart';

/// Caso de uso: eliminar una entrada junto con sus fotos.
class DeleteDiaryEntry {
  // Recibe el repositorio y el almacenamiento de fotos por constructor
  // (inyección de dependencias). Como son interfaces, en las pruebas se
  // le pueden pasar versiones falsas.
  DeleteDiaryEntry(this._repository, this._imageStorage);

  final DiaryRepository _repository;
  final ImageStorageService _imageStorage;

  /// Ejecuta el caso de uso. Al llamarse `call`, el objeto se puede usar
  /// como si fuera una función: `deleteDiaryEntry(entry)`.
  Future<void> call(DiaryEntry entry) async {
    // Si la entrada nunca se guardó (no tiene id), no hay nada que borrar.
    final id = entry.id;
    if (id == null) return;

    // Primero el registro: si falla, las fotos siguen intactas.
    await _repository.delete(id);
    // Después se borran del disco las fotos de la entrada, una por una.
    for (final path in entry.imagePaths) {
      await _imageStorage.delete(path);
    }
  }
}
