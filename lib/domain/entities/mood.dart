// Capa de dominio, Dart puro. Enum mejorado: cada valor guarda su
// emoji y su etiqueta, así la interfaz los muestra sin lógica extra.
/// Estado de ánimo asociado a una entrada del diario.
///
/// Se persiste en SQLite usando [name], por lo que renombrar un valor
/// requiere una migración de la base de datos.
enum Mood {
  great('😄', 'Radiante'),
  good('🙂', 'Bien'),
  neutral('😐', 'Normal'),
  sad('😢', 'Triste'),
  stressed('😫', 'Estresado');

  // Constructor const que asigna el emoji y la etiqueta de cada valor.
  const Mood(this.emoji, this.label);

  /// Emoji que representa el estado de ánimo en la interfaz.
  final String emoji;

  /// Etiqueta legible en español.
  final String label;

  /// Convierte el texto guardado en la base de datos a un [Mood].
  ///
  /// Si el valor no existe (datos corruptos o de una versión futura) se
  /// devuelve [Mood.neutral] en lugar de lanzar una excepción.
  static Mood fromName(String? name) {
    // Busca el valor cuyo nombre coincida; si ninguno coincide, orElse
    // devuelve neutral para que la app no falle.
    return Mood.values.firstWhere(
      (mood) => mood.name == name,
      orElse: () => Mood.neutral,
    );
  }
}
