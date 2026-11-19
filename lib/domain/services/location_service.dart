// Capa de dominio: interfaz del GPS. Solo usa la entidad GeoLocation y
// nunca el paquete geolocator; ese detalle queda en la capa de datos
// (GeolocatorLocationService). Las pruebas usan FakeLocationService.
import '../entities/geo_location.dart';

/// Acceso al GPS del dispositivo.
abstract interface class LocationService {
  /// Obtiene la posición actual.
  ///
  /// Gestiona internamente la solicitud de permisos. Puede lanzar
  /// `PermissionException`, `ServiceDisabledException` o
  /// `LocationTimeoutException`.
  Future<GeoLocation> getCurrentLocation();

  /// Abre los ajustes del sistema para encender el GPS.
  Future<bool> openLocationSettings();
}
