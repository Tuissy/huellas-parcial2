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
  const GeolocatorLocationService({
    this.timeout = const Duration(seconds: 15),
  });

  /// Tiempo máximo de espera por una posición nueva.
  final Duration timeout;

  @override
  Future<GeoLocation> getCurrentLocation() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      throw ServiceDisabledException(DeviceFeature.location);
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.unableToDetermine) {
      throw PermissionException(DeviceFeature.location);
    }
    if (permission == geo.LocationPermission.deniedForever) {
      throw PermissionException(DeviceFeature.location, permanentlyDenied: true);
    }

    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return _toGeoLocation(position);
    } on TimeoutException {
      developer.log('GPS sin respuesta; usando última posición conocida');
      final last = await geo.Geolocator.getLastKnownPosition();
      if (last != null) return _toGeoLocation(last);
      throw const LocationTimeoutException();
    } on geo.LocationServiceDisabledException {
      throw ServiceDisabledException(DeviceFeature.location);
    } on geo.PermissionDeniedException {
      throw PermissionException(DeviceFeature.location);
    } catch (error) {
      developer.log('Error de geolocator', error: error);
      throw HardwareUnavailableException(
        DeviceFeature.location,
        'No se pudo leer el GPS del dispositivo.',
        error,
      );
    }
  }

  @override
  Future<bool> openLocationSettings() => geo.Geolocator.openLocationSettings();

  GeoLocation _toGeoLocation(geo.Position position) => GeoLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
}
