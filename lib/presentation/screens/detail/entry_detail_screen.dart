// Pantalla de detalle de una entrada (capa de presentación). Muestra las
// fotos, el texto, el estado de ánimo, la fecha y la ubicación en un mapa.
// Material: los widgets visuales de Flutter.
import 'package:flutter/material.dart';

// Capa core: dependencias (AppScope), errores propios y el formato de fechas en
// español.
import '../../../core/di/app_dependencies.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_formatter.dart';
// Capa domain: las entidades DiaryEntry y GeoLocation.
import '../../../domain/entities/diary_entry.dart';
import '../../../domain/entities/geo_location.dart';
// Capa presentation: rutas con nombre y widgets reutilizables (mensajes,
// imagen, mapa, colores del ánimo, recarga al volver y vistas de error o
// vacío).
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
  // Constructor: la entrada es obligatoria; llega desde la lista como argumento
  // de la ruta con nombre entryDetail.
  const EntryDetailScreen({super.key, required this.entry});

  /// Entrada recibida desde la lista. Se muestra de inmediato (lo que
  /// permite la animación Hero) mientras se relee de la base de datos.
  final DiaryEntry entry;

  // Crea el objeto State que guarda los datos que cambian.
  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

/// Estado del detalle. Usa el mixin RouteAwareRefresh para recargar la entrada
/// cada vez que se vuelve a esta pantalla, por ejemplo después de editarla.
class _EntryDetailScreenState extends State<EntryDetailScreen>
    with RouteAwareRefresh {
  // Future con la lectura de la base de datos; lo usa el FutureBuilder.
  late Future<DiaryEntry?> _entryFuture;
  // Última versión conocida de la entrada: empieza con la que llegó de la
  // lista y se actualiza con cada lectura.
  late DiaryEntry _lastKnown = widget.entry;
  // Bandera para hacer la primera carga una sola vez.
  bool _initialized = false;

  /// Primero llama a super para que el mixin RouteAwareRefresh se suscriba al
  /// observador de rutas; después lanza la primera lectura de la base de
  /// datos, una sola vez.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _entryFuture = _load();
    }
  }

  /// Lee la versión más reciente de la entrada desde SQLite a través del
  /// repositorio. Devuelve null si la entrada ya no existe.
  Future<DiaryEntry?> _load() async {
    final id = widget.entry.id;
    // Si la entrada no tiene id (no está guardada), se usa tal cual.
    if (id == null) return widget.entry;
    // Consulta por id con el repositorio que entrega AppScope.
    final entry = await AppScope.of(context).diaryRepository.getById(id);
    // Si se encontró, se guarda como la última versión conocida.
    if (entry != null) _lastKnown = entry;
    return entry;
  }

  /// Viene del mixin RouteAwareRefresh: al volver a esta pantalla (por ejemplo,
  /// después de editar) se recarga la entrada.
  @override
  void onReturnToScreen() => _reload();

  /// Vuelve a leer la entrada. El cuerpo de setState es un bloque porque
  /// el callback no debe devolver un Future.
  void _reload() {
    // Asignar un Future nuevo dentro de setState hace que el FutureBuilder
    // vuelva a consultar y redibuje.
    setState(() {
      _entryFuture = _load();
    });
  }

  /// Abre el formulario de edición con rutas con nombre: Navigator.pushNamed
  /// con la entrada como argumento. Al volver, el mixin recarga los datos.
  Future<void> _edit(DiaryEntry entry) =>
      Navigator.pushNamed(context, AppRoutes.entryForm, arguments: entry);

  /// Elimina la entrada después de pedirle confirmación al usuario.
  Future<void> _delete(DiaryEntry entry) async {
    // Diálogo de confirmación con estilo destructivo, porque borrar no se
    // puede deshacer.
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
    // Si el usuario cancela o la pantalla ya se cerró, no se hace nada.
    if (!confirmed || !mounted) return;

    // try-catch y AppFeedback para mostrar errores sin cerrar la app.
    try {
      // Caso de uso DeleteDiaryEntry: borra el registro de SQLite y después
      // sus fotos.
      await AppScope.of(context).deleteDiaryEntry(entry);
      if (!mounted) return;
      // Mensaje de éxito y regreso a la pantalla anterior.
      AppFeedback.showMessage(context, 'Entrada eliminada', icon: Icons.check);
      Navigator.pop(context);
    } on AppException catch (error) {
      if (mounted) await AppFeedback.showError(context, error);
    }
  }

  /// Abre Google Maps con url_launcher (implementado en la capa data). Si no
  /// hay una aplicación que pueda abrirlo, el error se muestra con
  /// AppFeedback.
  Future<void> _openInGoogleMaps(GeoLocation location) async {
    try {
      await AppScope.of(context).mapsLauncher.openLocation(location);
    } on AppException catch (error) {
      if (mounted) await AppFeedback.showError(context, error);
    }
  }

  /// Abre el visor de fotos en pantalla completa en la foto tocada, con la ruta
  /// con nombre photoViewer y PhotoViewerArgs como argumentos.
  void _openPhoto(DiaryEntry entry, int index) {
    final id = entry.id;
    // PhotoViewerArgs necesita el id de la entrada; sin id no se abre.
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

  /// Construye la pantalla según el resultado de la lectura: error, entrada no
  /// encontrada o el contenido completo.
  @override
  Widget build(BuildContext context) {
    // FutureBuilder con initialData para dibujar desde el primer cuadro, sin
    // esperar a que termine la consulta.
    return FutureBuilder<DiaryEntry?>(
      future: _entryFuture,
      // initialData permite pintar la entrada en el primer frame, requisito
      // para que el Hero encuentre su destino durante la transición.
      initialData: _lastKnown,
      builder: (context, snapshot) {
        // Si la lectura falla, se muestra ErrorView con un botón para
        // reintentar.
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

        // Si la entrada ya no existe (por ejemplo, se borró), se muestra un
        // estado vacío.
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
        // Si todo está bien, se dibuja el contenido.
        return _buildContent(context, entry);
      },
    );
  }

  /// Contenido del detalle: cabecera desplegable con las fotos y debajo toda la
  /// información de la entrada.
  Widget _buildContent(BuildContext context, DiaryEntry entry) {
    // Tema y colores actuales de la app.
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Scaffold sin AppBar normal: la barra va dentro del CustomScrollView.
    return Scaffold(
      // CustomScrollView con slivers: permite que la cabecera se encoja al
      // desplazar el contenido.
      body: CustomScrollView(
        slivers: [
          // SliverAppBar: cabecera de 320 de alto que se encoge al desplazar y
          // queda fija arriba (pinned). Su color es el del estado de ánimo.
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: entry.mood.color,
            foregroundColor: Colors.white,
            // Acciones de la barra: editar y eliminar la entrada.
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
            // FlexibleSpaceBar: el fondo de la cabecera es la galería de
            // fotos.
            flexibleSpace: FlexibleSpaceBar(
              background: _HeaderGallery(
                entry: entry,
                onOpen: (i) => _openPhoto(entry, i),
              ),
            ),
          ),
          // El resto del contenido va en una lista de slivers con margen.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList.list(
              children: [
                // Título de la entrada en negrita.
                Text(
                  entry.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Chips con el estado de ánimo (emoji y nombre) y la hora.
                // Wrap los pasa a otra línea si no caben.
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
                // Fecha larga con la primera letra en mayúscula.
                Text(
                  _capitalize(DateFormatter.longDate(entry.createdAt)),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                // Línea divisoria y luego el texto del día. SelectableText
                // permite seleccionar y copiar el texto.
                const Divider(height: 32),
                SelectableText(
                  entry.content.isEmpty ? 'Sin texto.' : entry.content,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 28),
                // Sección de ubicación: el mapa o un aviso si no hay
                // coordenadas.
                Text('¿Dónde estaba?', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _LocationSection(entry: entry, onOpenMaps: _openInGoogleMaps),
                // Si la entrada se editó al menos un minuto después de
                // crearla, se muestra cuándo fue la última edición.
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

  /// Pone en mayúscula la primera letra, porque la fecha en español empieza
  /// con el día de la semana en minúscula.
  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// Cabecera con las fotos. Cada página tiene su propio Hero; la primera
/// comparte etiqueta con la miniatura de la lista.
class _HeaderGallery extends StatefulWidget {
  // Recibe la entrada y la función para abrir la foto tocada.
  const _HeaderGallery({required this.entry, required this.onOpen});

  final DiaryEntry entry;
  final ValueChanged<int> onOpen;

  // Crea el estado que recuerda la página actual.
  @override
  State<_HeaderGallery> createState() => _HeaderGalleryState();
}

/// Estado de la galería: guarda la foto visible para pintar los puntos
/// indicadores.
class _HeaderGalleryState extends State<_HeaderGallery> {
  // Índice de la foto que se está viendo.
  int _page = 0;

  /// Dibuja la galería o, si no hay fotos, un fondo con el emoji del estado de
  /// ánimo.
  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

    // Sin fotos: se muestra el emoji del ánimo. Usa la misma etiqueta Hero que
    // la tarjeta de la lista, así la animación también funciona.
    if (!entry.hasImages) {
      return Hero(
        tag: HeroTags.entryImage(entry.id),
        child: MoodPlaceholder(mood: entry.mood, emojiSize: 96),
      );
    }

    // Con fotos: Stack con las fotos, un degradado y los puntos indicadores
    // encima.
    return Stack(
      fit: StackFit.expand,
      children: [
        // PageView para deslizar entre fotos; al cambiar de página se
        // actualiza _page con setState.
        PageView.builder(
          itemCount: entry.imagePaths.length,
          onPageChanged: (page) => setState(() => _page = page),
          // Al tocar una foto se abre el visor en pantalla completa.
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => widget.onOpen(index),
            // Hero: misma etiqueta que en la lista para que la foto vuele. La
            // foto 0 coincide con la miniatura de la lista y cada foto coincide
            // con la del visor.
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
        // Puntos indicadores de página, solo si hay más de una foto.
        if (entry.imagePaths.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < entry.imagePaths.length; i++)
                  // El punto de la foto actual se alarga y se pinta en blanco,
                  // con animación gracias a AnimatedContainer.
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

/// Sección de ubicación: mapa interactivo, coordenadas y botón para abrir
/// Google Maps. Si no hay ubicación, muestra un aviso.
class _LocationSection extends StatelessWidget {
  // Recibe la entrada y la función de la pantalla que abre Google Maps.
  const _LocationSection({required this.entry, required this.onOpenMaps});

  final DiaryEntry entry;
  final ValueChanged<GeoLocation> onOpenMaps;

  // Dibuja el mapa o el aviso según si la entrada tiene ubicación.
  @override
  Widget build(BuildContext context) {
    final location = entry.location;
    final theme = Theme.of(context);

    // Entrada guardada sin GPS: tarjeta informativa.
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
        // Mapa interactivo con la ubicación de la entrada (OpenStreetMap con
        // flutter_map).
        LocationMap(location: location),
        const SizedBox(height: 12),
        // Coordenadas con la precisión del GPS en metros, si se conoce.
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
        // Botón para abrir Google Maps con url_launcher.
        FilledButton.tonalIcon(
          onPressed: () => onOpenMaps(location),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Abrir en Google Maps'),
        ),
      ],
    );
  }
}
