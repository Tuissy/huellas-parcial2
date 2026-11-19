import 'dart:developer' as developer;

import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/services/maps_launcher.dart';

/// Abre Google Maps (app o navegador) con las coordenadas guardadas.
class UrlMapsLauncher implements MapsLauncher {
  // Implementa la interfaz MapsLauncher del dominio con url_launcher
  // (inversión de dependencias): el dominio no sabe cómo se abre el mapa.
  const UrlMapsLauncher();

  /// URL universal documentada por Google: abre la app de Google Maps si
  /// está instalada o, si no, la versión web.
  static Uri buildUri(GeoLocation location) => Uri.https(
    'www.google.com',
    '/maps/search/',
    // query lleva "latitud,longitud"; api=1 es parámetro obligatorio de
    // este formato de URL.
    {'api': '1', 'query': '${location.latitude},${location.longitude}'},
  );

  /// Abre Google Maps en las coordenadas de la entrada.
  @override
  Future<void> openLocation(GeoLocation location) async {
    final uri = buildUri(location);
    try {
      // externalApplication: se abre fuera de la app (Maps o el navegador).
      // launchUrl devuelve false si ninguna aplicación puede abrir la URL.
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const ExternalAppException(
          'No hay una aplicación disponible para abrir el mapa.',
        );
      }
      // try-catch: la excepción propia se deja pasar y cualquier otro error
      // se traduce a ExternalAppException con mensaje en español.
    } on AppException {
      rethrow;
    } catch (error) {
      developer.log('No se pudo abrir Google Maps', error: error);
      throw ExternalAppException('No se pudo abrir Google Maps.', error);
    }
  }
}
