// Capa de dominio. Entidad del dominio: Dart puro, sin Flutter ni
// paquetes externos; solo importa otras piezas del propio dominio.
import 'geo_location.dart';
import 'mood.dart';

/// Entidad de dominio: un registro del diario personal.
///
/// Es inmutable; para modificarla se usa [copyWith]. No conoce nada de
/// SQLite ni de Flutter, lo que permite probarla y reutilizarla (capa de
/// dominio independiente de la infraestructura).
class DiaryEntry {
  // Constructor const con parámetros nombrados. El id y la ubicación
  // son opcionales y la lista de fotos empieza vacía por defecto.
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
  // Datos principales: título, texto, estado de ánimo y fechas de
  // creación y de última edición. Todos los campos son final, por eso
  // la entidad es inmutable.
  final String title;
  final String content;
  final Mood mood;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Rutas absolutas de las fotos adjuntas (la primera es la portada).
  final List<String> imagePaths;

  /// Ubicación GPS capturada al guardar la entrada.
  final GeoLocation? location;

  // Getters calculados (no se guardan, se calculan al pedirlos): si la
  // entrada es nueva, si tiene fotos o ubicación, y cuál es la portada.
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
    // Cada campo toma el valor nuevo si se pasó, o conserva el actual
    // con el operador ??. La ubicación además se puede borrar con
    // clearLocation.
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

  // Representación en texto, útil para depurar.
  @override
  String toString() => 'DiaryEntry(id: $id, title: $title)';
}
