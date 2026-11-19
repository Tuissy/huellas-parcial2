// Capa de dominio, Dart puro. Al ser un objeto de valor, dos
// ubicaciones con las mismas coordenadas se consideran iguales.
/// Objeto de valor inmutable con las coordenadas GPS de una entrada.
class GeoLocation {
  // Latitud y longitud son obligatorias; la precisión es opcional.
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  // Coordenadas en grados decimales, como las entrega el GPS.
  final double latitude;
  final double longitude;

  /// Precisión horizontal reportada por el GPS (en metros), si se conoce.
  final double? accuracyMeters;

  // Se redondea a 5 decimales, que equivale a una precisión cercana a
  // un metro.
  /// Coordenadas formateadas para mostrarse al usuario.
  String get formatted =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  // Igualdad por valor: se sobrescriben == y hashCode juntos, como pide
  // Dart, para comparar por contenido y no por posición en memoria.
  @override
  bool operator ==(Object other) =>
      other is GeoLocation &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracyMeters == accuracyMeters;

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyMeters);

  // Texto para depurar: coordenadas y precisión, o "?" si no se conoce.
  @override
  String toString() => 'GeoLocation($formatted ±${accuracyMeters ?? '?'} m)';
}
