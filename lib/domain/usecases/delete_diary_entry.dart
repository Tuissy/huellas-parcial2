import '../entities/diary_entry.dart';
import '../repositories/diary_repository.dart';
import '../services/image_storage_service.dart';

/// Caso de uso: eliminar una entrada junto con sus fotos.
class DeleteDiaryEntry {
  DeleteDiaryEntry(this._repository, this._imageStorage);

  final DiaryRepository _repository;
  final ImageStorageService _imageStorage;

  Future<void> call(DiaryEntry entry) async {
    final id = entry.id;
    if (id == null) return;

    // Primero el registro: si falla, las fotos siguen intactas.
    await _repository.delete(id);
    for (final path in entry.imagePaths) {
      await _imageStorage.delete(path);
    }
  }
}
