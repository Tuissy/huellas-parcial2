import 'dart:developer' as developer;

import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/services/maps_launcher.dart';

/// Abre Google Maps (app o navegador) con las coordenadas guardadas.
class UrlMapsLauncher implements MapsLauncher {
  const UrlMapsLauncher();

  /// URL universal documentada por Google: abre la app de Google Maps si
  /// está instalada o, si no, la versión web.
  static Uri buildUri(GeoLocation location) => Uri.https(
        'www.google.com',
        '/maps/search/',
        {
          'api': '1',
          'query': '${location.latitude},${location.longitude}',
        },
      );

  @override
  Future<void> openLocation(GeoLocation location) async {
    final uri = buildUri(location);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const ExternalAppException(
          'No hay una aplicación disponible para abrir el mapa.',
        );
      }
    } on AppException {
      rethrow;
    } catch (error) {
      developer.log('No se pudo abrir Google Maps', error: error);
      throw ExternalAppException('No se pudo abrir Google Maps.', error);
    }
  }
}
