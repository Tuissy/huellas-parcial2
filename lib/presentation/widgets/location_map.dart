// ARCHIVO: location_map.dart. Concepto: flutter_map con mosaicos de
// OpenStreetMap, un mapa gratuito que no necesita clave de API. Aquí están
// las piezas del mapa que comparten el detalle de una entrada y el mapa de
// recuerdos.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/geo_location.dart';

/// Configuración común de la capa de mosaicos de OpenStreetMap.
TileLayer buildOsmTileLayer() => TileLayer(
  // Plantilla de la dirección de cada mosaico: z es el nivel de zoom y x, y la
  // posición del cuadro. flutter_map descarga solo los cuadros que se ven en
  // pantalla.
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  // Requerido por la política de uso de OpenStreetMap.
  userAgentPackageName: 'com.example.parcial2',
  // OpenStreetMap ofrece mosaicos hasta el zoom 19; si se acerca más, se
  // amplían los de ese nivel.
  maxNativeZoom: 19,
);

/// Atribución obligatoria de OpenStreetMap.
Widget buildOsmAttribution() => const RichAttributionWidget(
  // La licencia de OpenStreetMap exige mostrar el crédito sobre el mapa; este
  // widget lo coloca en una esquina.
  attributions: [TextSourceAttribution('Colaboradores de OpenStreetMap')],
);

/// Mapa interactivo (zoom y desplazamiento) centrado en una ubicación,
/// con un marcador y un botón para volver a centrar.
class LocationMap extends StatefulWidget {
  // Recibe la ubicación (latitud, longitud y precisión) y la altura, 220 por
  // defecto. Es StatefulWidget porque necesita un MapController que se crea una
  // vez y se libera al final.
  const LocationMap({super.key, required this.location, this.height = 220});

  final GeoLocation location;
  final double height;

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  // MapController permite mover el mapa desde el código (botón 'Centrar'). El
  // zoom 16 muestra el nivel de las calles.
  final MapController _controller = MapController();
  static const double _zoom = 16;

  // Convierte nuestra GeoLocation (dominio) al LatLng que usa flutter_map. Así
  // el dominio no depende del paquete del mapa.
  LatLng get _point =>
      LatLng(widget.location.latitude, widget.location.longitude);

  // Liberamos el controlador del mapa al destruir el widget.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Recortamos el mapa con esquinas redondeadas y le damos la altura
    // indicada. El Stack permite poner el botón 'Centrar' encima del mapa.
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              // Opciones iniciales: centrado en el punto con zoom 16. Se
              // permiten todos los gestos menos la rotación (con operaciones
              // de bits quitamos esa bandera).
              options: MapOptions(
                initialCenter: _point,
                initialZoom: _zoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              // Capas del mapa, de abajo hacia arriba: mosaicos, círculo de
              // precisión, marcador y créditos.
              children: [
                buildOsmTileLayer(),
                // Si el GPS informó la precisión, dibujamos un círculo con
                // ese radio en metros reales (useRadiusInMeter) para mostrar el
                // margen de error de la posición.
                if (widget.location.accuracyMeters != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _point,
                        radius: widget.location.accuracyMeters!,
                        useRadiusInMeter: true,
                        color: scheme.primary.withValues(alpha: 0.15),
                        borderColor: scheme.primary.withValues(alpha: 0.5),
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
                // Marcador rojo en la posición. alignment topCenter coloca el
                // ícono encima del punto, así la punta del pin señala el
                // lugar exacto.
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _point,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.location_on,
                        size: 48,
                        color: scheme.error,
                      ),
                    ),
                  ],
                ),
                buildOsmAttribution(),
              ],
            ),
            // Botón 'Centrar' en la esquina superior derecha: si el usuario
            // movió el mapa, lo devuelve al punto y al zoom inicial.
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: 'Centrar',
                icon: const Icon(Icons.my_location),
                onPressed: () => _controller.move(_point, _zoom),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
