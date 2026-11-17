import '../../core/errors/app_exception.dart';
import '../entities/diary_entry.dart';
import '../entities/geo_location.dart';
import '../entities/mood.dart';
import '../repositories/diary_repository.dart';
import '../services/image_storage_service.dart';

/// Datos capturados por el formulario, antes de persistirse.
class DiaryEntryDraft {
  const DiaryEntryDraft({
    this.original,
    required this.title,
    required this.content,
    required this.mood,
    required this.imagePaths,
    this.location,
  });

  /// Entrada que se está editando, o `null` si es nueva.
  final DiaryEntry? original;
  final String title;
  final String content;
  final Mood mood;

  /// Mezcla de rutas permanentes (fotos ya guardadas) y temporales (fotos
  /// recién tomadas o elegidas de la galería).
  final List<String> imagePaths;
  final GeoLocation? location;
}

/// Caso de uso: guardar (crear o actualizar) una entrada del diario.
///
/// Responsabilidad única: coordinar el repositorio y el almacenamiento de
/// imágenes para que una entrada nunca quede apuntando a fotos temporales
/// ni deje archivos huérfanos si algo falla.
class SaveDiaryEntry {
  SaveDiaryEntry(
    this._repository,
    this._imageStorage, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DiaryRepository _repository;
  final ImageStorageService _imageStorage;
  final DateTime Function() _clock;

  static const int maxImages = 4;

  Future<DiaryEntry> call(DiaryEntryDraft draft) async {
    final title = draft.title.trim();
    if (title.isEmpty) {
      throw const ValidationException('Escribe un título para tu entrada.');
    }
    if (draft.imagePaths.length > maxImages) {
      throw const ValidationException('Solo puedes adjuntar $maxImages fotos.');
    }

    // 1. Copiar las fotos temporales al almacenamiento permanente.
    final persistedPaths = <String>[];
    final newlyCopied = <String>[];
    try {
      for (final path in draft.imagePaths) {
        final persisted = await _imageStorage.persist(path);
        persistedPaths.add(persisted);
        if (persisted != path) newlyCopied.add(persisted);
      }

      // 2. Guardar el registro en la base de datos.
      final now = _clock();
      final original = draft.original;
      final DiaryEntry saved;
      if (original == null) {
        saved = await _repository.create(
          DiaryEntry(
            title: title,
            content: draft.content.trim(),
            mood: draft.mood,
            createdAt: now,
            updatedAt: now,
            imagePaths: persistedPaths,
            location: draft.location,
          ),
        );
      } else {
        saved = await _repository.update(
          original.copyWith(
            title: title,
            content: draft.content.trim(),
            mood: draft.mood,
            updatedAt: now,
            imagePaths: persistedPaths,
            location: draft.location,
            clearLocation: draft.location == null,
          ),
        );
        // 3. Borrar del disco las fotos que el usuario quitó al editar.
        for (final oldPath in original.imagePaths) {
          if (!persistedPaths.contains(oldPath)) {
            await _imageStorage.delete(oldPath);
          }
        }
      }
      return saved;
    } catch (_) {
      // Si algo falló, se revierten las copias para no dejar basura.
      for (final path in newlyCopied) {
        await _imageStorage.delete(path);
      }
      rethrow;
    }
  }
}
