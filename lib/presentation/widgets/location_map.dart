import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/geo_location.dart';

/// Configuración común de la capa de mosaicos de OpenStreetMap.
TileLayer buildOsmTileLayer() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  // Requerido por la política de uso de OpenStreetMap.
  userAgentPackageName: 'com.example.parcial2',
  maxNativeZoom: 19,
);

/// Atribución obligatoria de OpenStreetMap.
Widget buildOsmAttribution() => const RichAttributionWidget(
  attributions: [TextSourceAttribution('Colaboradores de OpenStreetMap')],
);

/// Mapa interactivo (zoom y desplazamiento) centrado en una ubicación,
/// con un marcador y un botón para volver a centrar.
class LocationMap extends StatefulWidget {
  const LocationMap({super.key, required this.location, this.height = 220});

  final GeoLocation location;
  final double height;

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  final MapController _controller = MapController();
  static const double _zoom = 16;

  LatLng get _point =>
      LatLng(widget.location.latitude, widget.location.longitude);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _point,
                initialZoom: _zoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                buildOsmTileLayer(),
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
