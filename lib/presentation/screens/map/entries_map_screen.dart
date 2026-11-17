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

  @override
  State<EntriesMapScreen> createState() => _EntriesMapScreenState();
}

class _EntriesMapScreenState extends State<EntriesMapScreen>
    with RouteAwareRefresh {
  Future<List<DiaryEntry>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<DiaryEntry>> _load() async {
    final entries = await AppScope.of(context).diaryRepository.getAll();
    return entries.where((entry) => entry.hasLocation).toList();
  }

  @override
  void onReturnToScreen() => _reload();

  /// El cuerpo de setState es un bloque: el callback no debe devolver un
  /// Future.
  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _showPreview(DiaryEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _EntryPreviewSheet(
        entry: entry,
        onOpen: () {
          Navigator.pop(sheetContext);
          Navigator.pushNamed(context, AppRoutes.entryDetail, arguments: entry);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de recuerdos')),
      drawer: const AppDrawer(currentRoute: AppRoutes.map),
      body: FutureBuilder<List<DiaryEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LoadingView(message: 'Ubicando tus recuerdos…');
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return ErrorView(
              message: error is AppException
                  ? error.message
                  : 'No se pudo cargar el mapa.',
              onRetry: _reload,
            );
          }
          final entries = snapshot.data ?? const <DiaryEntry>[];
          if (entries.isEmpty) {
            return const EmptyView(
              icon: Icons.location_searching,
              title: 'Aún no hay lugares',
              message:
                  'Las entradas que guardes con ubicación GPS aparecerán aquí.',
            );
          }
          return _buildMap(entries);
        },
      ),
    );
  }

  Widget _buildMap(List<DiaryEntry> entries) {
    final points = [
      for (final entry in entries)
        LatLng(entry.location!.latitude, entry.location!.longitude),
    ];

    final options = points.length == 1
        ? MapOptions(initialCenter: points.first, initialZoom: 15)
        : MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(64),
              maxZoom: 16,
            ),
          );

    return FlutterMap(
      options: options,
      children: [
        buildOsmTileLayer(),
        MarkerLayer(
          markers: [
            for (var i = 0; i < entries.length; i++)
              Marker(
                point: points[i],
                width: 48,
                height: 48,
                child: GestureDetector(
                  onTap: () => _showPreview(entries[i]),
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
                    child: Text(
                      entries[i].mood.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ),
          ],
        ),
        buildOsmAttribution(),
      ],
    );
  }
}

class _EntryPreviewSheet extends StatelessWidget {
  const _EntryPreviewSheet({required this.entry, required this.onOpen});

  final DiaryEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
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
