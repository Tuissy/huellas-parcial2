// Capa de dominio: interfaz para abrir mapas externos. La implementa
// UrlMapsLauncher (capa de datos) con el paquete url_launcher, y las
// pruebas usan FakeMapsLauncher.
import '../entities/geo_location.dart';

/// Abre una aplicación de mapas externa (Google Maps) en unas coordenadas.
abstract interface class MapsLauncher {
  /// Lanza `ExternalAppException` si no hay aplicación que pueda abrirlo.
  Future<void> openLocation(GeoLocation location);
}
