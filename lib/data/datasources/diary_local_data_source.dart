import 'package:sqflite/sqflite.dart';

import '../models/diary_entry_model.dart';
import 'diary_database.dart';

/// Fuente de datos local: ejecuta las consultas SQL sobre la tabla de
/// entradas. Solo conoce modelos y SQL; la conversión a entidades y el
/// manejo de errores se hacen en el repositorio.
class DiaryLocalDataSource {
  DiaryLocalDataSource(this._database);

  final DiaryDatabase _database;

  static const String _table = DiaryDatabase.entriesTable;
  static const String _orderBy = 'created_at DESC';

  Future<List<DiaryEntryModel>> findAll() async {
    final db = await _database.database;
    final rows = await db.query(_table, orderBy: _orderBy);
    return rows.map(DiaryEntryModel.fromMap).toList();
  }

  Future<DiaryEntryModel?> findById(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : DiaryEntryModel.fromMap(rows.first);
  }

  /// Búsqueda por título o contenido. Se usan parámetros (`?`) para evitar
  /// inyección SQL.
  Future<List<DiaryEntryModel>> search(String query) async {
    final db = await _database.database;
    final pattern = '%${query.trim()}%';
    final rows = await db.query(
      _table,
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: [pattern, pattern],
      orderBy: _orderBy,
    );
    return rows.map(DiaryEntryModel.fromMap).toList();
  }

  Future<int> insert(DiaryEntryModel model) async {
    final db = await _database.database;
    return db.insert(
      _table,
      model.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Devuelve el número de filas afectadas.
  Future<int> update(DiaryEntryModel model) async {
    final db = await _database.database;
    return db.update(
      _table,
      model.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _database.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final db = await _database.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM $_table');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
