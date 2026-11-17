import '../entities/diary_entry.dart';

/// Contrato de acceso a los registros del diario.
///
/// La capa de presentación y los casos de uso dependen de esta abstracción
/// y no de SQLite (Principio de Inversión de Dependencias). Las
/// implementaciones deben lanzar `StorageException` ante cualquier fallo.
abstract interface class DiaryRepository {
  /// Devuelve todas las entradas, de la más reciente a la más antigua.
  Future<List<DiaryEntry>> getAll();

  /// Busca una entrada por su id. Devuelve `null` si no existe.
  Future<DiaryEntry?> getById(int id);

  /// Busca entradas cuyo título o contenido contenga [query].
  Future<List<DiaryEntry>> search(String query);

  /// Inserta una entrada nueva y la devuelve con su `id` asignado.
  Future<DiaryEntry> create(DiaryEntry entry);

  /// Actualiza una entrada existente.
  Future<DiaryEntry> update(DiaryEntry entry);

  /// Elimina la entrada con el [id] indicado.
  Future<void> delete(int id);

  /// Número total de entradas guardadas.
  Future<int> count();
}
