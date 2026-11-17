import 'package:flutter_test/flutter_test.dart';
import 'package:parcial2/core/errors/app_exception.dart';
import 'package:parcial2/domain/entities/geo_location.dart';
import 'package:parcial2/domain/entities/mood.dart';
import 'package:parcial2/domain/usecases/delete_diary_entry.dart';
import 'package:parcial2/domain/usecases/save_diary_entry.dart';

import '../helpers/fakes.dart';

void main() {
  late InMemoryDiaryRepository repository;
  late FakeImageStorage storage;
  late SaveDiaryEntry save;
  final now = DateTime(2026, 11, 17, 12);

  setUp(() {
    repository = InMemoryDiaryRepository();
    storage = FakeImageStorage();
    save = SaveDiaryEntry(repository, storage, clock: () => now);
  });

  test(
    'crea una entrada copiando las fotos y guardando la ubicación',
    () async {
      const location = GeoLocation(latitude: 1, longitude: 2);
      final saved = await save(
        const DiaryEntryDraft(
          title: '  Mi día  ',
          content: 'texto',
          mood: Mood.good,
          imagePaths: ['tmp/foto.jpg'],
          location: location,
        ),
      );

      expect(saved.id, isNotNull);
      expect(saved.title, 'Mi día');
      expect(saved.imagePaths, ['perm/tmp/foto.jpg']);
      expect(saved.location, location);
      expect(saved.createdAt, now);
    },
  );

  test('rechaza un título vacío', () {
    expect(
      () => save(
        const DiaryEntryDraft(
          title: '   ',
          content: 'algo',
          mood: Mood.good,
          imagePaths: [],
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('al editar borra del disco las fotos que se quitaron', () async {
    final original = await save(
      const DiaryEntryDraft(
        title: 'A',
        content: '',
        mood: Mood.good,
        imagePaths: ['perm/1.jpg', 'perm/2.jpg'],
      ),
    );

    final edited = await save(
      DiaryEntryDraft(
        original: original,
        title: 'A editada',
        content: '',
        mood: Mood.sad,
        imagePaths: const ['perm/2.jpg'],
      ),
    );

    expect(edited.id, original.id);
    expect(edited.imagePaths, ['perm/2.jpg']);
    expect(storage.deleted, ['perm/1.jpg']);
  });

  test('si falla la base de datos revierte las copias de fotos', () async {
    repository.failOnWrite = true;

    await expectLater(
      save(
        const DiaryEntryDraft(
          title: 'Fallará',
          content: '',
          mood: Mood.good,
          imagePaths: ['tmp/x.jpg'],
        ),
      ),
      throwsA(isA<StorageException>()),
    );
    expect(storage.deleted, ['perm/tmp/x.jpg']);
  });

  test('eliminar una entrada borra también sus fotos', () async {
    final entry = await save(
      const DiaryEntryDraft(
        title: 'Con foto',
        content: '',
        mood: Mood.good,
        imagePaths: ['tmp/a.jpg'],
      ),
    );

    await DeleteDiaryEntry(repository, storage)(entry);

    expect(await repository.count(), 0);
    expect(storage.deleted, ['perm/tmp/a.jpg']);
  });
}
