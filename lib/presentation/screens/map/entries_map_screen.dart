import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/diary_entry.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/entry_image.dart';
import '../../widgets/location_map.dart';
import '../../widgets/mood_style.dart';
import '../../widgets/route_aware_refresh.dart';
import '../../widgets/state_views.dart';

/// "Mapa de recuerdos": todas las entradas con ubicación en un mapa.
class EntriesMapScreen extends StatefulWidget {
  const EntriesMapScreen({super.key});

  // Crea el objeto State, que guarda lo que cambia en esta pantalla.
  @override
  State<EntriesMapScreen> createState() => _EntriesMapScreenState();
}

/// Estado del mapa de recuerdos.
///
/// También usa RouteAwareRefresh (RouteAware): al volver a esta pantalla
/// se recargan los marcadores, por ejemplo si se borró una entrada.
class _EntriesMapScreenState extends State<EntriesMapScreen>
    with RouteAwareRefresh {
  // Future con las entradas que tienen ubicación; lo usa el FutureBuilder.
  Future<List<DiaryEntry>>? _future;

  // Primera carga: el operador ??= evita repetir la consulta si este
  // método se llama más de una vez.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  /// Trae todas las entradas y se queda solo con las que tienen
  /// ubicación GPS, porque las demás no se pueden poner en el mapa.
  Future<List<DiaryEntry>> _load() async {
    final entries = await AppScope.of(context).diaryRepository.getAll();
    return entries.where((entry) => entry.hasLocation).toList();
  }

  // RouteAware: recargar al volver a la pantalla.
  @override
  void onReturnToScreen() => _reload();

  /// El cuerpo de setState es un bloque: el callback no debe devolver un
  /// Future.
  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  /// Al tocar un marcador se abre una hoja desde abajo
  /// (showModalBottomSheet) con un resumen de la entrada.
  void _showPreview(DiaryEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _EntryPreviewSheet(
        entry: entry,
        // Botón "Ver entrada": primero cierra la hoja y luego abre el
        // detalle con una ruta con nombre, pasando la entrada.
        onOpen: () {
          Navigator.pop(sheetContext);
          Navigator.pushNamed(context, AppRoutes.entryDetail, arguments: entry);
        },
      ),
    );
  }

  // Scaffold con AppBar y Drawer; el body depende del FutureBuilder.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de recuerdos')),
      // Menú lateral compartido, con "Mapa" marcado como la opción actual.
      drawer: const AppDrawer(currentRoute: AppRoutes.map),
      // FutureBuilder con sus estados: cargando, error, vacío y datos.
      body: FutureBuilder<List<DiaryEntry>>(
        future: _future,
        builder: (context, snapshot) {
          // Cargando por primera vez: CircularProgressIndicator.
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LoadingView(message: 'Ubicando tus recuerdos…');
          }
          // Error: mensaje amigable y botón para reintentar la carga.
          if (snapshot.hasError) {
            final error = snapshot.error;
            return ErrorView(
              message: error is AppException
                  ? error.message
                  : 'No se pudo cargar el mapa.',
              onRetry: _reload,
            );
          }
          // Vacío: todavía no hay entradas guardadas con ubicación.
          final entries = snapshot.data ?? const <DiaryEntry>[];
          if (entries.isEmpty) {
            return const EmptyView(
              icon: Icons.location_searching,
              title: 'Aún no hay lugares',
              message:
                  'Las entradas que guardes con ubicación GPS aparecerán aquí.',
            );
          }
          // Datos: se dibuja el mapa con un marcador por entrada.
          return _buildMap(entries);
        },
      ),
    );
  }

  /// Mapa interactivo con flutter_map y OpenStreetMap: se puede mover y
  /// hacer zoom, y cada entrada aparece como un marcador.
  Widget _buildMap(List<DiaryEntry> entries) {
    // Convierte la ubicación de cada entrada en coordenadas LatLng.
    final points = [
      for (final entry in entries)
        LatLng(entry.location!.latitude, entry.location!.longitude),
    ];

    // Encuadre inicial: con un solo punto se centra en él con zoom 15;
    // con varios, la cámara se ajusta para que se vean todos (CameraFit),
    // con un margen de 64 y sin acercarse más allá del zoom 16.
    final options = points.length == 1
        ? MapOptions(initialCenter: points.first, initialZoom: 15)
        : MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(64),
              maxZoom: 16,
            ),
          );

    // El mapa se arma con capas apiladas, de abajo hacia arriba.
    return FlutterMap(
      options: options,
      children: [
        // Capa 1: las imágenes (tiles) del mapa de OpenStreetMap.
        buildOsmTileLayer(),
        // Capa 2: un marcador por cada entrada con ubicación.
        MarkerLayer(
          markers: [
            for (var i = 0; i < entries.length; i++)
              Marker(
                point: points[i],
                width: 48,
                height: 48,
                // Al tocar el marcador se abre la vista previa.
                child: GestureDetector(
                  onTap: () => _showPreview(entries[i]),
                  // Círculo con el color del estado de ánimo, borde
                  // blanco y sombra para que resalte sobre el mapa.
                  child: Container(
                    decoration: BoxDecoration(
                      color: entries[i].mood.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(blurRadius: 6, color: Colors.black26),
                      ],
                    ),
                    alignment: Alignment.center,
                    // Dentro va el emoji del estado de ánimo.
                    child: Text(
                      entries[i].mood.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Capa 3: créditos de OpenStreetMap, que exige su licencia.
        buildOsmAttribution(),
      ],
    );
  }
}

/// Contenido de la hoja inferior: miniatura, título, fecha, el inicio
/// del texto y un botón para abrir la entrada completa.
class _EntryPreviewSheet extends StatelessWidget {
  const _EntryPreviewSheet({required this.entry, required this.onOpen});

  // Entrada que se resume y acción del botón "Ver entrada".
  final DiaryEntry entry;
  final VoidCallback onOpen;

  // Dibuja la vista previa de la entrada.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // SafeArea evita que el contenido quede bajo las barras del sistema.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        // Columna del tamaño mínimo, para que la hoja no ocupe toda la
        // pantalla.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Miniatura de 72 x 72: la primera foto de la entrada o,
                // si no tiene, el color y emoji del ánimo. cacheWidth
                // reduce el tamaño de la imagen en memoria.
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox.square(
                    dimension: 72,
                    child: EntryImage(
                      path: entry.coverImage,
                      mood: entry.mood,
                      cacheWidth: 240,
                      emojiSize: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Textos a la derecha: título en una línea, fecha
                // (por ejemplo "Hoy · 10:30") y dos líneas del contenido.
                // Expanded les da el espacio que sobra en la fila.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DateFormatter.relative(entry.createdAt),
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Botón para ir al detalle completo de la entrada.
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ver entrada'),
            ),
          ],
        ),
      ),
    );
  }
}
