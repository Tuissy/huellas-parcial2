import 'dart:developer' as developer;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';

/// Abre y versiona la base de datos SQLite de la aplicación.
///
/// Mantiene una única conexión compartida (se abre la primera vez que se
/// necesita). Para las pruebas se puede inyectar otra [DatabaseFactory] y
/// una ruta en memoria.
class DiaryDatabase {
  DiaryDatabase({DatabaseFactory? factory, String? path})
      : _factory = factory ?? databaseFactory,
        _customPath = path;

  static const String fileName = 'huellas.db';
  static const int version = 1;

  static const String entriesTable = 'diary_entries';

  final DatabaseFactory _factory;
  final String? _customPath;
  Future<Database>? _opening;

  /// Conexión a la base de datos. Si dos llamadas llegan a la vez,
  /// ambas esperan el mismo `Future` y no se abre la base dos veces.
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    try {
      final path =
          _customPath ?? p.join(await _factory.getDatabasesPath(), fileName);
      return await _factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: version,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    } catch (error, stack) {
      // Se permite reintentar en la siguiente llamada.
      _opening = null;
      developer.log('Error al abrir la BD', error: error, stackTrace: stack);
      throw StorageException('No se pudo abrir la base de datos.', error);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Fechas en milisegundos (INTEGER) para ordenar de forma eficiente.
    // image_paths guarda un arreglo JSON de rutas relativas.
    await db.execute('''
      CREATE TABLE $entriesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        mood TEXT NOT NULL,
        image_paths TEXT NOT NULL DEFAULT '[]',
        latitude REAL,
        longitude REAL,
        location_accuracy REAL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_entries_created_at ON $entriesTable (created_at DESC)',
    );
  }

  /// Punto de extensión para futuras migraciones de esquema.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    developer.log('Migrando BD de v$oldVersion a v$newVersion');
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }
}
