import 'dart:convert';

import '../../domain/entities/diary_entry.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/entities/mood.dart';

/// Modelo de datos (DTO) de una entrada del diario.
///
/// Traduce entre la entidad de dominio [DiaryEntry] y sus representaciones
/// persistentes: un `Map` para SQLite y un JSON para exportar/serializar.
/// Las rutas de imágenes se guardan como un arreglo JSON dentro de una
/// columna TEXT y las coordenadas como columnas REAL independientes.
class DiaryEntryModel {
  const DiaryEntryModel({
    this.id,
    required this.title,
    required this.content,
    required this.mood,
    required this.imagePaths,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });

  final int? id;
  final String title;
  final String content;
  final String mood;
  final List<String> imagePaths;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracy;
  final int createdAtMillis;
  final int updatedAtMillis;

  // ---------------------------------------------------------------------
  // Dominio <-> modelo
  // ---------------------------------------------------------------------

  /// Construye el modelo a partir de la entidad. [mapPath] permite
  /// transformar cada ruta de imagen (p. ej. de absoluta a relativa).
  factory DiaryEntryModel.fromEntity(
    DiaryEntry entry, {
    String Function(String path)? mapPath,
  }) {
    final transform = mapPath ?? (String path) => path;
    return DiaryEntryModel(
      id: entry.id,
      title: entry.title,
      content: entry.content,
      mood: entry.mood.name,
      imagePaths: entry.imagePaths.map(transform).toList(growable: false),
      latitude: entry.location?.latitude,
      longitude: entry.location?.longitude,
      locationAccuracy: entry.location?.accuracyMeters,
      createdAtMillis: entry.createdAt.millisecondsSinceEpoch,
      updatedAtMillis: entry.updatedAt.millisecondsSinceEpoch,
    );
  }

  DiaryEntry toEntity({String Function(String path)? mapPath}) {
    final transform = mapPath ?? (String path) => path;
    final lat = latitude;
    final lng = longitude;
    return DiaryEntry(
      id: id,
      title: title,
      content: content,
      mood: Mood.fromName(mood),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMillis),
      imagePaths: imagePaths.map(transform).toList(growable: false),
      location: (lat != null && lng != null)
          ? GeoLocation(
              latitude: lat,
              longitude: lng,
              accuracyMeters: locationAccuracy,
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------
  // SQLite
  // ---------------------------------------------------------------------

  /// Fila de la tabla `diary_entries`. El `id` se omite si es nulo para que
  /// SQLite lo genere con AUTOINCREMENT.
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'content': content,
      'mood': mood,
      'image_paths': jsonEncode(imagePaths),
      'latitude': latitude,
      'longitude': longitude,
      'location_accuracy': locationAccuracy,
      'created_at': createdAtMillis,
      'updated_at': updatedAtMillis,
    };
  }

  factory DiaryEntryModel.fromMap(Map<String, Object?> map) {
    return DiaryEntryModel(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      mood: map['mood'] as String? ?? Mood.neutral.name,
      imagePaths: _decodePaths(map['image_paths']),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationAccuracy: (map['location_accuracy'] as num?)?.toDouble(),
      createdAtMillis: map['created_at'] as int? ?? 0,
      updatedAtMillis: map['updated_at'] as int? ?? 0,
    );
  }

  // ---------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------

  /// Representación JSON con tipos nativos (fechas ISO-8601 y objeto de
  /// ubicación anidado), pensada para respaldos o intercambio de datos.
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'mood': mood,
      'imagePaths': imagePaths,
      'location': latitude == null || longitude == null
          ? null
          : {
              'latitude': latitude,
              'longitude': longitude,
              'accuracy': locationAccuracy,
            },
      'createdAt': DateTime.fromMillisecondsSinceEpoch(
        createdAtMillis,
      ).toIso8601String(),
      'updatedAt': DateTime.fromMillisecondsSinceEpoch(
        updatedAtMillis,
      ).toIso8601String(),
    };
  }

  factory DiaryEntryModel.fromJson(Map<String, Object?> json) {
    final location = json['location'] as Map<String, Object?>?;
    return DiaryEntryModel(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      mood: json['mood'] as String? ?? Mood.neutral.name,
      imagePaths: (json['imagePaths'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      locationAccuracy: (location?['accuracy'] as num?)?.toDouble(),
      createdAtMillis: _parseDate(json['createdAt']),
      updatedAtMillis: _parseDate(json['updatedAt']),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory DiaryEntryModel.fromJsonString(String source) =>
      DiaryEntryModel.fromJson(jsonDecode(source) as Map<String, Object?>);

  // ---------------------------------------------------------------------
  // Utilidades privadas
  // ---------------------------------------------------------------------

  /// Decodifica el arreglo JSON de rutas. Ante datos corruptos devuelve una
  /// lista vacía en lugar de romper la carga de todo el diario.
  static List<String> _decodePaths(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } on FormatException {
      // Se ignora: la entrada se muestra sin fotos.
    }
    return const [];
  }

  static int _parseDate(Object? raw) {
    if (raw is int) return raw;
    if (raw is String) {
      return DateTime.tryParse(raw)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }
}
