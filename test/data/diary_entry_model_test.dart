import 'package:flutter_test/flutter_test.dart';
import 'package:parcial2/data/models/diary_entry_model.dart';
import 'package:parcial2/domain/entities/diary_entry.dart';
import 'package:parcial2/domain/entities/geo_location.dart';
import 'package:parcial2/domain/entities/mood.dart';

void main() {
  final created = DateTime(2026, 11, 17, 9, 30);
  final entry = DiaryEntry(
    id: 7,
    title: 'Presentación en la Anáhuac Mayab',
    content: 'Presenté el avance de Huellas en clase.',
    mood: Mood.great,
    createdAt: created,
    updatedAt: created.add(const Duration(hours: 1)),
    imagePaths: const ['diary_images/a.jpg', 'diary_images/b.jpg'],
    location: const GeoLocation(
      latitude: 21.1112,
      longitude: -89.6124,
      accuracyMeters: 8.5,
    ),
  );

  group('DiaryEntryModel – SQLite (Map)', () {
    test('toMap guarda rutas como arreglo JSON y coordenadas como REAL', () {
      final map = DiaryEntryModel.fromEntity(entry).toMap();

      expect(map['image_paths'], '["diary_images/a.jpg","diary_images/b.jpg"]');
      expect(map['latitude'], 21.1112);
      expect(map['longitude'], -89.6124);
      expect(map['mood'], 'great');
      expect(map['created_at'], created.millisecondsSinceEpoch);
    });

    test('ida y vuelta Map -> entidad conserva todos los datos', () {
      final map = DiaryEntryModel.fromEntity(entry).toMap();
      final restored = DiaryEntryModel.fromMap(map).toEntity();

      expect(restored.id, entry.id);
      expect(restored.title, entry.title);
      expect(restored.mood, Mood.great);
      expect(restored.imagePaths, entry.imagePaths);
      expect(restored.location, entry.location);
      expect(restored.createdAt, entry.createdAt);
    });

    test('datos corruptos no rompen la carga', () {
      final model = DiaryEntryModel.fromMap({
        'id': 1,
        'title': 'x',
        'content': '',
        'mood': 'desconocido',
        'image_paths': '{no es json',
        'created_at': 0,
        'updated_at': 0,
      });
      final restored = model.toEntity();

      expect(restored.imagePaths, isEmpty);
      expect(restored.mood, Mood.neutral);
      expect(restored.location, isNull);
    });
  });

  group('DiaryEntryModel – JSON', () {
    test('ida y vuelta JSON conserva ubicación anidada y fechas ISO', () {
      final json = DiaryEntryModel.fromEntity(entry).toJsonString();
      expect(json, contains('"createdAt":"2026-11-17T09:30:00.000"'));
      expect(json, contains('"location":{"latitude":21.1112'));

      final restored = DiaryEntryModel.fromJsonString(json).toEntity();
      expect(restored.location, entry.location);
      expect(restored.imagePaths, entry.imagePaths);
      expect(restored.updatedAt, entry.updatedAt);
    });

    test('entrada sin ubicación serializa location como null', () {
      final noLocation = entry.copyWith(clearLocation: true);
      final json = DiaryEntryModel.fromEntity(noLocation).toJson();
      expect(json['location'], isNull);
    });
  });
}
