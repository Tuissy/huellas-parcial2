import 'package:flutter_test/flutter_test.dart';
import 'package:parcial2/data/datasources/diary_database.dart';
import 'package:parcial2/data/datasources/diary_local_data_source.dart';
import 'package:parcial2/data/repositories/sqlite_diary_repository.dart';
import 'package:parcial2/data/services/local_image_storage_service.dart';
import 'package:parcial2/domain/entities/diary_entry.dart';
import 'package:parcial2/domain/entities/geo_location.dart';
import 'package:parcial2/domain/entities/mood.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pruebas de integración con un SQLite real (en memoria) mediante FFI.
void main() {
  sqfliteFfiInit();

  late DiaryDatabase database;
  late SqliteDiaryRepository repository;
  const docs = '/docs';

  setUp(() {
    database = DiaryDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqliteDiaryRepository(
      DiaryLocalDataSource(database),
      LocalImageStorageService(docs),
    );
  });

  tearDown(() => database.close());

  DiaryEntry entry(String title, DateTime date, {GeoLocation? location}) =>
      DiaryEntry(
        title: title,
        content: 'Contenido de $title',
        mood: Mood.good,
        createdAt: date,
        updatedAt: date,
        imagePaths: ['$docs/diary_images/$title.jpg'],
        location: location,
      );

  test(
    'crea y lee entradas ordenadas de la más reciente a la más antigua',
    () async {
      await repository.create(entry('vieja', DateTime(2026, 1, 1)));
      await repository.create(entry('nueva', DateTime(2026, 6, 1)));

      final all = await repository.getAll();
      expect(all.map((e) => e.title), ['nueva', 'vieja']);
      expect(await repository.count(), 2);
    },
  );

  test('guarda rutas relativas y las devuelve absolutas', () async {
    final saved = await repository.create(entry('foto', DateTime(2026)));

    final db = await database.database;
    final row = (await db.query(DiaryDatabase.entriesTable)).single;
    expect(row['image_paths'], '["diary_images/foto.jpg"]');

    final loaded = await repository.getById(saved.id!);
    expect(loaded!.imagePaths, ['$docs/diary_images/foto.jpg']);
  });

  test('persiste y recupera las coordenadas GPS', () async {
    const location = GeoLocation(
      latitude: 19.4326,
      longitude: -99.1332,
      accuracyMeters: 5,
    );
    final saved = await repository.create(
      entry('gps', DateTime(2026), location: location),
    );

    expect((await repository.getById(saved.id!))!.location, location);
  });

  test('busca por título o contenido', () async {
    await repository.create(entry('Tacos', DateTime(2026)));
    await repository.create(entry('Parque', DateTime(2026)));

    final results = await repository.search('taco');
    expect(results.single.title, 'Tacos');
  });

  test('actualiza y elimina', () async {
    final saved = await repository.create(entry('Original', DateTime(2026)));

    await repository.update(saved.copyWith(title: 'Editada'));
    expect((await repository.getById(saved.id!))!.title, 'Editada');

    await repository.delete(saved.id!);
    expect(await repository.getById(saved.id!), isNull);
  });
}
