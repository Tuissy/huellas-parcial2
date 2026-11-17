import 'package:flutter/material.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/diary_entry.dart';
import '../../../domain/entities/geo_location.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/entry_image.dart';
import '../../widgets/location_map.dart';
import '../../widgets/mood_style.dart';
import '../../widgets/route_aware_refresh.dart';
import '../../widgets/state_views.dart';

/// Detalle de una entrada: foto(s) con Hero, texto, estado de ánimo y
/// mapa interactivo con la ubicación guardada.
class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({super.key, required this.entry});

  /// Entrada recibida desde la lista. Se muestra de inmediato (lo que
  /// permite la animación Hero) mientras se relee de la base de datos.
  final DiaryEntry entry;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen>
    with RouteAwareRefresh {
  late Future<DiaryEntry?> _entryFuture;
  late DiaryEntry _lastKnown = widget.entry;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _entryFuture = _load();
    }
  }

  Future<DiaryEntry?> _load() async {
    final id = widget.entry.id;
    if (id == null) return widget.entry;
    final entry = await AppScope.of(context).diaryRepository.getById(id);
    if (entry != null) _lastKnown = entry;
    return entry;
  }

  @override
  void onReturnToScreen() => _reload();

  /// Vuelve a leer la entrada. El cuerpo de setState es un bloque porque
  /// el callback no debe devolver un Future.
  void _reload() {
    setState(() {
      _entryFuture = _load();
    });
  }

  Future<void> _edit(DiaryEntry entry) =>
      Navigator.pushNamed(context, AppRoutes.entryForm, arguments: entry);

  Future<void> _delete(DiaryEntry entry) async {
    final confirmed = await AppFeedback.confirm(
      context,
      icon: Icons.delete_outline,
      title: '¿Eliminar entrada?',
      message:
          'Se borrarán "${entry.title}" y sus fotos. '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await AppScope.of(context).deleteDiaryEntry(entry);
      if (!mounted) return;
      AppFeedback.showMessage(context, 'Entrada eliminada', icon: Icons.check);
      Navigator.pop(context);
    } on AppException catch (error) {
      if (mounted) await AppFeedback.showError(context, error);
    }
  }

  Future<void> _openInGoogleMaps(GeoLocation location) async {
    try {
      await AppScope.of(context).mapsLauncher.openLocation(location);
    } on AppException catch (error) {
      if (mounted) await AppFeedback.showError(context, error);
    }
  }

  void _openPhoto(DiaryEntry entry, int index) {
    final id = entry.id;
    if (id == null) return;
    Navigator.pushNamed(
      context,
      AppRoutes.photoViewer,
      arguments: PhotoViewerArgs(
        entryId: id,
        imagePaths: entry.imagePaths,
        initialIndex: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DiaryEntry?>(
      future: _entryFuture,
      // initialData permite pintar la entrada en el primer frame, requisito
      // para que el Hero encuentre su destino durante la transición.
      initialData: _lastKnown,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(
              message: error is AppException
                  ? error.message
                  : 'No se pudo cargar.',
              onRetry: _reload,
            ),
          );
        }

        final entry = snapshot.data;
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyView(
              icon: Icons.delete_sweep_outlined,
              title: 'Entrada no encontrada',
              message: 'Es posible que haya sido eliminada.',
            ),
          );
        }
        return _buildContent(context, entry);
      },
    );
  }

  Widget _buildContent(BuildContext context, DiaryEntry entry) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: entry.mood.color,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(entry),
              ),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(entry),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeaderGallery(
                entry: entry,
                onOpen: (i) => _openPhoto(entry, i),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList.list(
              children: [
                Text(
                  entry.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      avatar: Text(entry.mood.emoji),
                      label: Text(entry.mood.label),
                      side: BorderSide(color: entry.mood.color),
                    ),
                    Chip(
                      avatar: const Icon(Icons.schedule, size: 18),
                      label: Text(DateFormatter.time(entry.createdAt)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _capitalize(DateFormatter.longDate(entry.createdAt)),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 32),
                SelectableText(
                  entry.content.isEmpty ? 'Sin texto.' : entry.content,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 28),
                Text('¿Dónde estaba?', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _LocationSection(entry: entry, onOpenMaps: _openInGoogleMaps),
                if (entry.updatedAt.difference(entry.createdAt).inMinutes >
                    0) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Editado: ${DateFormatter.relative(entry.updatedAt)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// Cabecera con las fotos. Cada página tiene su propio Hero; la primera
/// comparte etiqueta con la miniatura de la lista.
class _HeaderGallery extends StatefulWidget {
  const _HeaderGallery({required this.entry, required this.onOpen});

  final DiaryEntry entry;
  final ValueChanged<int> onOpen;

  @override
  State<_HeaderGallery> createState() => _HeaderGalleryState();
}

class _HeaderGalleryState extends State<_HeaderGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

    if (!entry.hasImages) {
      return Hero(
        tag: HeroTags.entryImage(entry.id),
        child: MoodPlaceholder(mood: entry.mood, emojiSize: 96),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: entry.imagePaths.length,
          onPageChanged: (page) => setState(() => _page = page),
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => widget.onOpen(index),
            child: Hero(
              tag: HeroTags.entryImage(entry.id, index),
              child: EntryImage(
                path: entry.imagePaths[index],
                mood: entry.mood,
              ),
            ),
          ),
        ),
        // Degradado para que los iconos del AppBar sean legibles.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
        ),
        if (entry.imagePaths.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < entry.imagePaths.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.entry, required this.onOpenMaps});

  final DiaryEntry entry;
  final ValueChanged<GeoLocation> onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final location = entry.location;
    final theme = Theme.of(context);

    if (location == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.location_off_outlined),
          title: const Text('Sin ubicación'),
          subtitle: const Text('Esta entrada se guardó sin coordenadas GPS.'),
          textColor: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LocationMap(location: location),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.place_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                location.formatted +
                    (location.accuracyMeters != null
                        ? '  (±${location.accuracyMeters!.round()} m)'
                        : ''),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => onOpenMaps(location),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Abrir en Google Maps'),
        ),
      ],
    );
  }
}
