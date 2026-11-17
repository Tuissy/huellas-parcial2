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
  SqliteDiaryRepository(this._dataSource, this._imageStorage);

  final DiaryLocalDataSource _dataSource;
  final ImageStorageService _imageStorage;

  @override
  Future<List<DiaryEntry>> getAll() {
    return _guard('cargar tus diarios', () async {
      final models = await _dataSource.findAll();
      return models.map(_toEntity).toList();
    });
  }

  @override
  Future<DiaryEntry?> getById(int id) {
    return _guard('cargar la entrada', () async {
      final model = await _dataSource.findById(id);
      return model == null ? null : _toEntity(model);
    });
  }

  @override
  Future<List<DiaryEntry>> search(String query) {
    if (query.trim().isEmpty) return getAll();
    return _guard('buscar en tus diarios', () async {
      final models = await _dataSource.search(query);
      return models.map(_toEntity).toList();
    });
  }

  @override
  Future<DiaryEntry> create(DiaryEntry entry) {
    return _guard('guardar la entrada', () async {
      final id = await _dataSource.insert(_toModel(entry));
      return entry.copyWith(id: id);
    });
  }

  @override
  Future<DiaryEntry> update(DiaryEntry entry) {
    return _guard('actualizar la entrada', () async {
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

  @override
  Future<void> delete(int id) {
    return _guard('eliminar la entrada', () => _dataSource.delete(id));
  }

  @override
  Future<int> count() => _guard('contar tus diarios', _dataSource.count);

  DiaryEntry _toEntity(DiaryEntryModel model) =>
      model.toEntity(mapPath: _imageStorage.toAbsolutePath);

  DiaryEntryModel _toModel(DiaryEntry entry) =>
      DiaryEntryModel.fromEntity(entry, mapPath: _imageStorage.toStoredPath);

  /// Ejecuta [action] dentro de un try-catch y traduce los errores.
  Future<T> _guard<T>(String operation, Future<T> Function() action) async {
    try {
      return await action();
    } on AppException {
      rethrow;
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
