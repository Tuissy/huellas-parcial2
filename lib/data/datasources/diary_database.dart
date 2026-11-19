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
  // Clase con una sola responsabilidad (SRP): abrir, crear y versionar la
  // base de datos SQLite con el paquete sqflite.
  // El constructor recibe la fábrica y la ruta como opcionales: si no se
  // pasan, usa la fábrica real del dispositivo (inyección de dependencias).
  DiaryDatabase({DatabaseFactory? factory, String? path})
    : _factory = factory ?? databaseFactory,
      _customPath = path;

  // Nombre del archivo y versión del esquema. sqflite compara esta versión
  // con la guardada en el archivo para decidir si debe crear la base
  // (onCreate) o migrarla (onUpgrade) cuando la versión sube.
  static const String fileName = 'huellas.db';
  static const int version = 1;

  // Nombre de la tabla en un solo lugar para no repetir el texto.
  static const String entriesTable = 'diary_entries';

  // Fábrica de sqflite, ruta opcional y _opening, que guarda el Future de
  // la apertura: la conexión se abre una sola vez y luego se reutiliza en
  // todas las consultas.
  final DatabaseFactory _factory;
  final String? _customPath;
  Future<Database>? _opening;

  /// Conexión a la base de datos. Si dos llamadas llegan a la vez,
  /// ambas esperan el mismo `Future` y no se abre la base dos veces.
  Future<Database> get database => _opening ??= _open();

  /// Abre el archivo de la base de datos, o lo crea si todavía no existe.
  Future<Database> _open() async {
    // try-catch: si algo falla al abrir, el error técnico se traduce a una
    // StorageException con un mensaje en español para el usuario.
    try {
      // Ruta del archivo: la personalizada (en pruebas) o la carpeta de bases
      // de datos que entrega el sistema más el nombre 'huellas.db'.
      final path =
          _customPath ?? p.join(await _factory.getDatabasesPath(), fileName);
      // openDatabase recibe la versión y dos callbacks: onCreate se ejecuta la
      // primera vez (crea las tablas) y onUpgrade cuando sube la versión.
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
      // Se registra el error real en el log y se lanza uno entendible.
      developer.log('Error al abrir la BD', error: error, stackTrace: stack);
      throw StorageException('No se pudo abrir la base de datos.', error);
    }
  }

  /// Se ejecuta solo la primera vez que se crea la base: aquí se define el
  /// esquema con CREATE TABLE.
  Future<void> _onCreate(Database db, int version) async {
    // CREATE TABLE de las entradas del diario:
    // - id entero autoincremental como llave primaria.
    // - título, contenido y estado de ánimo como TEXT obligatorios.
    // - Coordenadas en columnas REAL (latitud, longitud y precisión) que
    //   aceptan nulo, porque una entrada puede no tener ubicación.
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
    // Índice sobre la fecha de creación: la lista principal se ordena por
    // created_at de forma descendente y así esa consulta es más rápida.
    await db.execute(
      'CREATE INDEX idx_entries_created_at ON $entriesTable (created_at DESC)',
    );
  }

  /// Punto de extensión para futuras migraciones de esquema.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // En la versión 1 todavía no hay migraciones; solo se deja registro.
    // Si en el futuro se agrega una columna, se sube "version" y aquí se
    // escribe el ALTER TABLE correspondiente.
    developer.log('Migrando BD de v$oldVersion a v$newVersion');
  }

  /// Cierra la conexión si estaba abierta y borra el Future guardado, para
  /// que la próxima llamada vuelva a abrir la base.
  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }
}
