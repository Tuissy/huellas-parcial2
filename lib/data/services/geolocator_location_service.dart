import 'dart:async';
import 'dart:developer' as developer;

import 'package:geolocator/geolocator.dart' as geo;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/services/location_service.dart';

/// GPS mediante el paquete geolocator.
///
/// Flujo: servicio encendido → permiso → posición precisa con tiempo
/// límite → si se agota, última posición conocida como respaldo.
class GeolocatorLocationService implements LocationService {
  // Adaptador del plugin geolocator: implementa la interfaz
  // LocationService del dominio (inversión de dependencias). El tiempo
  // límite se puede cambiar al crearlo; por defecto son 15 segundos.
  const GeolocatorLocationService({this.timeout = const Duration(seconds: 15)});

  /// Tiempo máximo de espera por una posición nueva.
  final Duration timeout;

  /// Obtiene la ubicación actual del dispositivo como un GeoLocation.
  @override
  Future<GeoLocation> getCurrentLocation() async {
    // 1) Se revisa que el servicio de ubicación (GPS) esté encendido.
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      throw ServiceDisabledException(DeviceFeature.location);
    }

    // 2) Se consulta el permiso y, si todavía no se ha dado, se pide.
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    // Permiso negado vs bloqueado: "denied" permite volver a preguntar más
    // adelante; "deniedForever" obliga a ir a los ajustes del sistema.
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.unableToDetermine) {
      throw PermissionException(DeviceFeature.location);
    }
    if (permission == geo.LocationPermission.deniedForever) {
      throw PermissionException(
        DeviceFeature.location,
        permanentlyDenied: true,
      );
    }

    try {
      // 3) Se pide una posición de alta precisión con tiempo límite, para
      //    que la app no se quede esperando al GPS para siempre.
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return _toGeoLocation(position);
      // 4) Tiempo límite del GPS y última posición conocida: si el GPS no
      //    responde a tiempo, se usa la última posición que guardó el sistema.
      //    Si tampoco hay, se lanza LocationTimeoutException.
    } on TimeoutException {
      developer.log('GPS sin respuesta; usando última posición conocida');
      final last = await geo.Geolocator.getLastKnownPosition();
      if (last != null) return _toGeoLocation(last);
      throw const LocationTimeoutException();
      // Si el GPS se apaga o el permiso se retira durante la lectura, se
      // traducen a las mismas excepciones de la app.
    } on geo.LocationServiceDisabledException {
      throw ServiceDisabledException(DeviceFeature.location);
    } on geo.PermissionDeniedException {
      throw PermissionException(DeviceFeature.location);
      // Cualquier otro error se traduce a HardwareUnavailableException.
    } catch (error) {
      developer.log('Error de geolocator', error: error);
      throw HardwareUnavailableException(
        DeviceFeature.location,
        'No se pudo leer el GPS del dispositivo.',
        error,
      );
    }
  }

  /// Abre los ajustes del sistema para que el usuario encienda el GPS.
  @override
  Future<bool> openLocationSettings() => geo.Geolocator.openLocationSettings();

  /// Convierte la Position del plugin en la entidad GeoLocation del
  /// dominio, para que las demás capas no dependan de geolocator.
  GeoLocation _toGeoLocation(geo.Position position) => GeoLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracyMeters: position.accuracy,
  );
}
