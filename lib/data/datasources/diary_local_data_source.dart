import 'package:sqflite/sqflite.dart';

import '../models/diary_entry_model.dart';
import 'diary_database.dart';

/// Fuente de datos local: ejecuta las consultas SQL sobre la tabla de
/// entradas. Solo conoce modelos y SQL; la conversión a entidades y el
/// manejo de errores se hacen en el repositorio.
class DiaryLocalDataSource {
  // Responsabilidad única (SRP): esta clase solo ejecuta SQL con sqflite.
  // Recibe la DiaryDatabase por constructor (inyección de dependencias).
  DiaryLocalDataSource(this._database);

  final DiaryDatabase _database;

  // Nombre de la tabla y orden por defecto: lo más reciente primero.
  static const String _table = DiaryDatabase.entriesTable;
  static const String _orderBy = 'created_at DESC';

  /// Devuelve todas las entradas, de la más nueva a la más antigua.
  Future<List<DiaryEntryModel>> findAll() async {
    // Se obtiene la conexión compartida y se hace un SELECT con db.query.
    // Cada fila llega como un Map y se convierte en modelo con fromMap.
    final db = await _database.database;
    final rows = await db.query(_table, orderBy: _orderBy);
    return rows.map(DiaryEntryModel.fromMap).toList();
  }

  /// Busca una entrada por su id; devuelve null si no existe.
  Future<DiaryEntryModel?> findById(int id) async {
    final db = await _database.database;
    // SELECT con "WHERE id = ?" y LIMIT 1. El signo "?" se reemplaza de forma
    // segura con el valor de whereArgs.
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
    // El texto se rodea con % para que LIKE encuentre la palabra en cualquier
    // parte del título o del contenido.
    final pattern = '%${query.trim()}%';
    final rows = await db.query(
      _table,
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: [pattern, pattern],
      orderBy: _orderBy,
    );
    return rows.map(DiaryEntryModel.fromMap).toList();
  }

  /// Inserta una entrada nueva y devuelve el id que generó SQLite.
  Future<int> insert(DiaryEntryModel model) async {
    final db = await _database.database;
    // Se quita el id del mapa para que SQLite lo genere con AUTOINCREMENT.
    // ConflictAlgorithm.abort: si hay un conflicto, la operación falla en
    // lugar de sobrescribir datos.
    return db.insert(
      _table,
      model.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Devuelve el número de filas afectadas.
  Future<int> update(DiaryEntryModel model) async {
    final db = await _database.database;
    // UPDATE de todas las columnas menos el id, filtrando por el id del
    // modelo. Si devuelve 0, el repositorio sabe que la fila ya no existe.
    return db.update(
      _table,
      model.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  /// Borra la fila con ese id y devuelve cuántas filas se eliminaron.
  Future<int> delete(int id) async {
    final db = await _database.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Cuenta cuántas entradas hay guardadas en la tabla.
  Future<int> count() async {
    final db = await _database.database;
    // Consulta SQL directa con rawQuery. firstIntValue toma el número de la
    // primera fila y columna del resultado (0 si viene vacío).
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM $_table');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
