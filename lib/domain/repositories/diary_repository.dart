// Capa de dominio: interfaz (contrato). Este archivo dice QUÉ se puede
// hacer con las entradas del diario, no CÓMO se hace.
import '../entities/diary_entry.dart';

// ¿Por qué una interfaz? Las pantallas y los casos de uso dependen de
// esta abstracción; la capa de datos la implementa con SQLite
// (SqliteDiaryRepository) y las pruebas usan una versión en memoria
// (InMemoryDiaryRepository). Así se puede cambiar la base de datos
// sin tocar las pantallas.
// "abstract interface class": no se pueden crear objetos de este tipo
// y las demás clases solo pueden implementarla (implements), no
// heredarla.
/// Contrato de acceso a los registros del diario.
///
/// La capa de presentación y los casos de uso dependen de esta abstracción
/// y no de SQLite (Principio de Inversión de Dependencias). Las
/// implementaciones deben lanzar `StorageException` ante cualquier fallo.
abstract interface class DiaryRepository {
  // Lectura: listar, buscar por id y buscar por texto. Todo devuelve
  // Future porque leer de la base de datos es una operación asíncrona.
  /// Devuelve todas las entradas, de la más reciente a la más antigua.
  Future<List<DiaryEntry>> getAll();

  /// Busca una entrada por su id. Devuelve `null` si no existe.
  Future<DiaryEntry?> getById(int id);

  /// Busca entradas cuyo título o contenido contenga [query].
  Future<List<DiaryEntry>> search(String query);

  // Escritura: crear, actualizar y eliminar (junto con la lectura
  // forman el CRUD).
  /// Inserta una entrada nueva y la devuelve con su `id` asignado.
  Future<DiaryEntry> create(DiaryEntry entry);

  /// Actualiza una entrada existente.
  Future<DiaryEntry> update(DiaryEntry entry);

  /// Elimina la entrada con el [id] indicado.
  Future<void> delete(int id);

  // Se usa en la pantalla de ajustes para mostrar cuántas entradas hay.
  /// Número total de entradas guardadas.
  Future<int> count();
}
