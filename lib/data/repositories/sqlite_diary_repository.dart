import 'dart:developer' as developer;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/repositories/diary_repository.dart';
import '../../domain/services/image_storage_service.dart';
import '../datasources/diary_local_data_source.dart';
import '../models/diary_entry_model.dart';

/// Implementación de [DiaryRepository] respaldada por SQLite.
///
/// * Convierte modelos <-> entidades.
/// * Guarda rutas de imagen relativas y las devuelve absolutas.
/// * Envuelve cualquier error técnico en una [StorageException] con un
///   mensaje comprensible, de modo que la UI nunca reciba un
///   `DatabaseException` crudo.
class SqliteDiaryRepository implements DiaryRepository {
  // Patrón repositorio: implementa la interfaz DiaryRepository del dominio.
  // Esto muestra inversión de dependencias (los casos de uso dependen del
  // contrato y no de SQLite) y Liskov (se puede cambiar por otra
  // implementación, por ejemplo una falsa en las pruebas, sin romper nada).
  // Sus dependencias llegan por el constructor.
  SqliteDiaryRepository(this._dataSource, this._imageStorage);

  final DiaryLocalDataSource _dataSource;
  final ImageStorageService _imageStorage;

  /// Carga todas las entradas y las convierte de modelos a entidades.
  @override
  Future<List<DiaryEntry>> getAll() {
    return _guard('cargar tus diarios', () async {
      final models = await _dataSource.findAll();
      return models.map(_toEntity).toList();
    });
  }

  /// Carga una sola entrada por id, o null si no existe.
  @override
  Future<DiaryEntry?> getById(int id) {
    return _guard('cargar la entrada', () async {
      final model = await _dataSource.findById(id);
      return model == null ? null : _toEntity(model);
    });
  }

  /// Busca por texto; si la búsqueda está vacía, devuelve todas.
  @override
  Future<List<DiaryEntry>> search(String query) {
    if (query.trim().isEmpty) return getAll();
    return _guard('buscar en tus diarios', () async {
      final models = await _dataSource.search(query);
      return models.map(_toEntity).toList();
    });
  }

  /// Guarda una entrada nueva: la convierte a modelo, la inserta y devuelve
  /// la misma entidad, ahora con el id que asignó SQLite.
  @override
  Future<DiaryEntry> create(DiaryEntry entry) {
    return _guard('guardar la entrada', () async {
      final id = await _dataSource.insert(_toModel(entry));
      return entry.copyWith(id: id);
    });
  }

  /// Actualiza una entrada que ya existe en la base.
  @override
  Future<DiaryEntry> update(DiaryEntry entry) {
    return _guard('actualizar la entrada', () async {
      // Validaciones: no se puede actualizar algo que nunca se guardó, y si
      // ninguna fila cambió es porque la entrada fue borrada.
      if (entry.id == null) {
        throw const StorageException(
          'No se puede actualizar una entrada sin guardar.',
        );
      }
      final affected = await _dataSource.update(_toModel(entry));
      if (affected == 0) {
        throw const StorageException('La entrada ya no existe.');
      }
      return entry;
    });
  }

  /// Elimina la entrada de la base. Las fotos las borra el caso de uso.
  @override
  Future<void> delete(int id) {
    return _guard('eliminar la entrada', () => _dataSource.delete(id));
  }

  /// Cuenta las entradas guardadas.
  @override
  Future<int> count() => _guard('contar tus diarios', _dataSource.count);

  /// Modelo a entidad: las rutas relativas guardadas se vuelven absolutas.
  /// Se usan rutas relativas porque en iOS cambia la ruta del contenedor.
  DiaryEntry _toEntity(DiaryEntryModel model) =>
      model.toEntity(mapPath: _imageStorage.toAbsolutePath);

  /// Entidad a modelo: las rutas absolutas se guardan como relativas.
  DiaryEntryModel _toModel(DiaryEntry entry) =>
      DiaryEntryModel.fromEntity(entry, mapPath: _imageStorage.toStoredPath);

  /// Ejecuta [action] dentro de un try-catch y traduce los errores.
  Future<T> _guard<T>(String operation, Future<T> Function() action) async {
    // Un solo lugar para el manejo de errores de todas las operaciones.
    try {
      return await action();
      // Si ya es una AppException (con mensaje en español), se deja pasar.
    } on AppException {
      rethrow;
      // try-catch: cualquier otro error técnico (por ejemplo de SQLite) se
      // guarda en el log y se traduce a una StorageException en español.
    } catch (error, stack) {
      developer.log(
        'Error al $operation',
        name: 'SqliteDiaryRepository',
        error: error,
        stackTrace: stack,
      );
      throw StorageException('No se pudo $operation. Intenta de nuevo.', error);
    }
  }
}
