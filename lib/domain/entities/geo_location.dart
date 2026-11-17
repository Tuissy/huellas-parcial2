/// Objeto de valor inmutable con las coordenadas GPS de una entrada.
class GeoLocation {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;

  /// Precisión horizontal reportada por el GPS (en metros), si se conoce.
  final double? accuracyMeters;

  /// Coordenadas formateadas para mostrarse al usuario.
  String get formatted =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) =>
      other is GeoLocation &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracyMeters == accuracyMeters;

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyMeters);

  @override
  String toString() => 'GeoLocation($formatted ±${accuracyMeters ?? '?'} m)';
}
