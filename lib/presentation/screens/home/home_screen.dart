import 'package:flutter/material.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/diary_entry.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/entry_card.dart';
import '../../widgets/route_aware_refresh.dart';
import '../../widgets/state_views.dart';
import 'entry_search_delegate.dart';

/// Pantalla principal: lista de entradas del diario.
///
/// Carga los datos de SQLite con un [FutureBuilder] y vuelve a cargarlos
/// automáticamente al regresar de otra pantalla.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  // Crea el objeto State, que guarda lo que cambia en esta pantalla.
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Estado de la pantalla principal.
///
/// Usa el mixin RouteAwareRefresh (RouteAware): cuando el usuario vuelve
/// a esta pantalla desde otra, la lista se recarga sola.
class _HomeScreenState extends State<HomeScreen> with RouteAwareRefresh {
  // Future con la lista de entradas que consume el FutureBuilder. Se
  // guarda en una variable para no repetir la consulta en cada build.
  Future<List<DiaryEntry>>? _entriesFuture;

  // Primera carga de datos. El operador ??= hace que la consulta se lance
  // solo la primera vez, aunque este método se llame varias veces.
  @override
  void didChangeDependencies() {
    // Aquí el mixin se suscribe al RouteObserver para saber cuándo
    // volvemos a esta pantalla.
    super.didChangeDependencies();
    _entriesFuture ??= _loadEntries();
  }

  // Pide todas las entradas al repositorio que entrega AppScope
  // (inyección de dependencias). La pantalla no sabe nada de SQL: solo
  // usa la interfaz DiaryRepository de la capa de dominio.
  Future<List<DiaryEntry>> _loadEntries() =>
      AppScope.of(context).diaryRepository.getAll();

  // Vuelve a consultar la base de datos y redibuja la lista. Se usa al
  // jalar hacia abajo, en el botón Reintentar y al regresar a la pantalla.
  Future<void> _refresh() async {
    final future = _loadEntries();
    // Cuerpo de bloque: setState no debe devolver un Future.
    setState(() {
      _entriesFuture = future;
    });
    // Se espera el resultado para que el RefreshIndicator sepa cuándo
    // ocultar su indicador de carga.
    try {
      await future;
    } catch (_) {
      // El error se muestra en el FutureBuilder.
    }
  }

  // RouteAware: el mixin llama a este método al volver a la pantalla,
  // por ejemplo después de crear, editar o borrar una entrada.
  @override
  void onReturnToScreen() => _refresh();

  // Rutas con nombre: abre el detalle y le pasa la entrada como argumento.
  void _openDetail(DiaryEntry entry) =>
      Navigator.pushNamed(context, AppRoutes.entryDetail, arguments: entry);

  // Abre el formulario para escribir una entrada nueva (ruta con nombre).
  void _openForm() => Navigator.pushNamed(context, AppRoutes.entryForm);

  // Estructura de la pantalla: Scaffold con AppBar, Drawer, botón
  // flotante y el contenido principal en el body.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Barra superior con el título y el botón de búsqueda.
      appBar: AppBar(
        title: const Text('Mis diarios'),
        actions: [
          // Lupa: abre la búsqueda con SearchDelegate usando showSearch.
          // Le pasamos el repositorio para consultar y la función que
          // abre el detalle cuando se toca un resultado.
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: EntrySearchDelegate(
                repository: AppScope.of(context).diaryRepository,
                onOpen: _openDetail,
              ),
            ),
          ),
        ],
      ),
      // Menú lateral (Drawer) compartido; se le indica que estamos en la
      // pantalla de inicio para resaltarla.
      drawer: const AppDrawer(currentRoute: AppRoutes.home),
      // Botón flotante para crear una entrada nueva.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.edit_note),
        label: const Text('Nueva entrada'),
      ),
      // El contenido cambia según el estado de la carga de datos.
      body: _buildContent(),
    );
  }

  /// Contenido principal con FutureBuilder y sus estados: cargando,
  /// error, vacío y datos.
  Widget _buildContent() {
    return FutureBuilder<List<DiaryEntry>>(
      future: _entriesFuture,
      builder: (context, snapshot) {
        // Indica si la consulta a la base de datos sigue en curso.
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        // 1) Primera carga: indicador de progreso.
        // LoadingView muestra un CircularProgressIndicator con un texto.
        // Solo aparece si aún no hay datos; al recargar se deja la lista.
        if (isLoading && !snapshot.hasData) {
          return const LoadingView(message: 'Cargando tus diarios…');
        }

        // 2) Error: mensaje claro y botón de reintento (sin crash).
        // Si el error es nuestro (AppException) se muestra su mensaje
        // amigable; si no, uno genérico. Reintentar vuelve a cargar.
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ErrorView(
            message: error is AppException
                ? error.message
                : 'No pudimos cargar tus diarios.',
            onRetry: _refresh,
          );
        }

        // Lista recibida; si por algún motivo viene nula, se usa vacía.
        final entries = snapshot.data ?? const <DiaryEntry>[];

        // 3) Sin datos: estado vacío con llamada a la acción.
        // Se envuelve en RefreshIndicator y en un ListView con scroll
        // siempre activo para poder jalar y recargar aunque no haya nada.
        if (entries.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Ocupa el 70 % del alto de la pantalla (MediaQuery) para
                // que el mensaje quede centrado.
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.7,
                  // Ícono, título, explicación y un botón que invita a
                  // escribir la primera entrada.
                  child: EmptyView(
                    icon: Icons.auto_stories_outlined,
                    title: 'Aún no dejas ninguna huella',
                    message:
                        'Dicta o escribe cómo fue tu día, añade una foto '
                        'y guardaremos dónde estabas.',
                    action: FilledButton.icon(
                      onPressed: _openForm,
                      icon: const Icon(Icons.add),
                      label: const Text('Escribir mi primera entrada'),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 4) Datos: lista con animación escalonada.
        return Column(
          children: [
            // Recarga en segundo plano: barra fina sobre la lista. Solo
            // existe mientras carga (un indicador oculto seguiría
            // animándose y consumiendo batería).
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isLoading
                  ? const LinearProgressIndicator(minHeight: 2)
                  : const SizedBox(height: 2),
            ),
            // La lista ocupa el resto del alto disponible y se puede
            // jalar hacia abajo para recargar (RefreshIndicator).
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                // ListView.separated construye solo las filas visibles y
                // agrega un espacio entre cada una.
                child: ListView.separated(
                  // Margen inferior amplio para que el botón flotante no
                  // tape la última tarjeta.
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  // La primera fila es el resumen con tus huellas.
                  itemCount: entries.length + 1,
                  // Más espacio después del resumen que entre tarjetas.
                  separatorBuilder: (_, index) =>
                      SizedBox(height: index == 0 ? 16 : 10),
                  // Cada fila entra con la animación escalonada. La fila
                  // 0 es el resumen; las demás son tarjetas de entradas
                  // (por eso se usa index - 1). Tocar una abre su detalle.
                  itemBuilder: (context, index) => _StaggeredEntrance(
                    index: index,
                    child: index == 0
                        ? _SummaryBanner(entries: entries)
                        : EntryCard(
                            entry: entries[index - 1],
                            onTap: () => _openDetail(entries[index - 1]),
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Resumen al inicio de la lista: saludo según la hora y tus huellas
/// (recuerdos, lugares y fotos).
class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.entries});

  // Entradas con las que se calculan los totales.
  final List<DiaryEntry> entries;

  /// Saludo según la hora del dispositivo: mañana, tarde o noche.
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  // Dibuja la tarjeta de resumen con degradado, saludo y totales.
  @override
  Widget build(BuildContext context) {
    // Colores y textos del tema actual (claro u oscuro).
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Totales: entradas con ubicación GPS y suma de todas las fotos.
    final places = entries.where((entry) => entry.hasLocation).length;
    final photos = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.imagePaths.length,
    );
    // Función local que escribe singular o plural: "1 foto", "3 fotos".
    String plural(int n, String one, String many) =>
        '$n ${n == 1 ? one : many}';

    // Tarjeta con esquinas redondeadas y un degradado del color principal
    // hacia una versión más oscura del mismo color.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.3)!,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título del resumen.
            Text(
              'Tus huellas',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            // Saludo según la hora, seguido de una pregunta.
            Text(
              '${_greeting()}, ¿qué huella dejarás hoy?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 14),
            // Resumen con los recuerdos, lugares y fotos guardados. Wrap
            // pasa las etiquetas a otra línea si no caben en una.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Stat(
                  icon: Icons.auto_stories,
                  label: plural(entries.length, 'recuerdo', 'recuerdos'),
                ),
                _Stat(
                  icon: Icons.place,
                  label: plural(places, 'lugar', 'lugares'),
                ),
                _Stat(
                  icon: Icons.photo_camera,
                  label: plural(photos, 'foto', 'fotos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta pequeña del resumen: un ícono y un texto, por ejemplo
/// "3 fotos".
class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  // Ícono y texto que se muestran en la etiqueta.
  final IconData icon;
  final String label;

  // Dibuja la etiqueta con fondo semitransparente.
  @override
  Widget build(BuildContext context) {
    // Fondo blanco semitransparente con bordes redondeados.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      // Fila del tamaño justo de su contenido: ícono, espacio y texto.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animación de entrada escalonada: cada tarjeta aparece un poco después
/// que la anterior, deslizándose hacia arriba.
class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({required this.index, required this.child});

  // Posición de la fila en la lista y el widget que se va a animar.
  final int index;
  final Widget child;

  // Calcula el retraso de esta fila y aplica la animación.
  @override
  Widget build(BuildContext context) {
    // Cada fila espera 60 ms más que la anterior. Con clamp el retraso
    // deja de crecer a partir de la fila 8, para que no tarde demasiado.
    final delayMs = 60 * index.clamp(0, 8);
    // Duración total: 350 ms de animación más el retraso de la fila.
    final totalMs = 350 + delayMs;
    // TweenAnimationBuilder anima un valor de 0 a 1 al construirse la
    // fila. El Interval hace que el movimiento empiece después del
    // retraso, con una curva que frena suavemente al final.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOutCubic),
      // Con ese valor la fila pasa de transparente a visible y sube
      // 24 píxeles hasta su lugar.
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: child,
        ),
      ),
      // El hijo se pasa aparte para no reconstruirlo en cada cuadro.
      child: child,
    );
  }
}
