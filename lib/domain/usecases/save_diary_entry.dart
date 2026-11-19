// Capa de dominio. Caso de uso para guardar una entrada: aquí viven
// las reglas de negocio (título obligatorio, máximo de fotos, limpieza
// de archivos) para que no queden repartidas en las pantallas.
// Importa los errores de core para lanzar ValidationException.
import '../../core/errors/app_exception.dart';
import '../entities/diary_entry.dart';
import '../entities/geo_location.dart';
import '../entities/mood.dart';
import '../repositories/diary_repository.dart';
import '../services/image_storage_service.dart';

// Borrador: objeto simple que lleva los datos del formulario hasta el
// caso de uso. Todavía no es una entrada guardada.
/// Datos capturados por el formulario, antes de persistirse.
class DiaryEntryDraft {
  // Constructor const; original y location son opcionales.
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
  // Título, texto y estado de ánimo tal como los escribió el usuario.
  final String title;
  final String content;
  final Mood mood;

  /// Mezcla de rutas permanentes (fotos ya guardadas) y temporales (fotos
  /// recién tomadas o elegidas de la galería).
  final List<String> imagePaths;

  /// Ubicación de la entrada, o `null` si no tiene.
  final GeoLocation? location;
}

/// Caso de uso: guardar (crear o actualizar) una entrada del diario.
///
/// Responsabilidad única: coordinar el repositorio y el almacenamiento de
/// imágenes para que una entrada nunca quede apuntando a fotos temporales
/// ni deje archivos huérfanos si algo falla.
class SaveDiaryEntry {
  // Además de las dos dependencias, acepta un "reloj" opcional. En la
  // app se usa DateTime.now; en las pruebas se pasa una hora fija para
  // que los resultados sean predecibles.
  SaveDiaryEntry(
    this._repository,
    this._imageStorage, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  // Dependencias guardadas con el tipo de las interfaces del dominio.
  final DiaryRepository _repository;
  final ImageStorageService _imageStorage;
  final DateTime Function() _clock;

  /// Número máximo de fotos por entrada.
  static const int maxImages = 4;

  /// Ejecuta el caso de uso: valida, copia las fotos, guarda el registro
  /// y borra lo que sobre. Devuelve la entrada ya guardada.
  Future<DiaryEntry> call(DiaryEntryDraft draft) async {
    // Validaciones de negocio: el título no puede quedar vacío (trim
    // quita los espacios) y no se aceptan más de maxImages fotos. Si algo
    // no se cumple, se lanza ValidationException con un mensaje para el
    // usuario.
    final title = draft.title.trim();
    if (title.isEmpty) {
      throw const ValidationException('Escribe un título para tu entrada.');
    }
    if (draft.imagePaths.length > maxImages) {
      throw const ValidationException('Solo puedes adjuntar $maxImages fotos.');
    }

    // 1. Copiar las fotos temporales al almacenamiento permanente.
    // persistedPaths guarda todas las rutas finales; newlyCopied solo
    // las copias nuevas, para poder borrarlas si después algo falla.
    final persistedPaths = <String>[];
    final newlyCopied = <String>[];
    // Todo va dentro de un try: si falla cualquier paso, el catch de
    // abajo deshace las copias nuevas.
    try {
      for (final path in draft.imagePaths) {
        final persisted = await _imageStorage.persist(path);
        persistedPaths.add(persisted);
        // Si la ruta cambió es una copia nueva; si es igual, la foto
        // ya estaba guardada de antes.
        if (persisted != path) newlyCopied.add(persisted);
      }

      // 2. Guardar el registro en la base de datos.
      // La hora actual se pide al reloj inyectado.
      final now = _clock();
      final original = draft.original;
      final DiaryEntry saved;
      // Entrada nueva: se crea con la misma fecha de creación y de
      // edición.
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
        // Entrada existente: se actualiza a partir de la original con
        // copyWith. Si el borrador no trae ubicación, se borra la que
        // tenía.
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
        // Se hace después de actualizar el registro, nunca antes.
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
      // Luego de limpiar, rethrow relanza el mismo error para que la
      // capa de presentación se entere del fallo y lo muestre.
      rethrow;
    }
  }
}
