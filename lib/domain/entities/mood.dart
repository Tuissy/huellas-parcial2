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
    return Mood.values.firstWhere(
      (mood) => mood.name == name,
      orElse: () => Mood.neutral,
    );
  }
}
