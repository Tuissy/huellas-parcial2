import 'geo_location.dart';
import 'mood.dart';

/// Entidad de dominio: un registro del diario personal.
///
/// Es inmutable; para modificarla se usa [copyWith]. No conoce nada de
/// SQLite ni de Flutter, lo que permite probarla y reutilizarla (capa de
/// dominio independiente de la infraestructura).
class DiaryEntry {
  const DiaryEntry({
    this.id,
    required this.title,
    required this.content,
    required this.mood,
    required this.createdAt,
    required this.updatedAt,
    this.imagePaths = const [],
    this.location,
  });

  /// Identificador asignado por la base de datos. Es `null` mientras la
  /// entrada no se ha guardado.
  final int? id;
  final String title;
  final String content;
  final Mood mood;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Rutas absolutas de las fotos adjuntas (la primera es la portada).
  final List<String> imagePaths;

  /// Ubicación GPS capturada al guardar la entrada.
  final GeoLocation? location;

  bool get isNew => id == null;
  bool get hasImages => imagePaths.isNotEmpty;
  bool get hasLocation => location != null;
  String? get coverImage => hasImages ? imagePaths.first : null;

  /// Crea una copia modificando solo los campos indicados.
  ///
  /// [clearLocation] permite eliminar la ubicación explícitamente, ya que
  /// pasar `null` en [location] significa "no cambiar".
  DiaryEntry copyWith({
    int? id,
    String? title,
    String? content,
    Mood? mood,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? imagePaths,
    GeoLocation? location,
    bool clearLocation = false,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePaths: imagePaths ?? this.imagePaths,
      location: clearLocation ? null : (location ?? this.location),
    );
  }

  @override
  String toString() => 'DiaryEntry(id: $id, title: $title)';
}
