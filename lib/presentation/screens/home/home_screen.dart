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

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAwareRefresh {
  Future<List<DiaryEntry>>? _entriesFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entriesFuture ??= _loadEntries();
  }

  Future<List<DiaryEntry>> _loadEntries() =>
      AppScope.of(context).diaryRepository.getAll();

  Future<void> _refresh() async {
    final future = _loadEntries();
    // Cuerpo de bloque: setState no debe devolver un Future.
    setState(() {
      _entriesFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // El error se muestra en el FutureBuilder.
    }
  }

  @override
  void onReturnToScreen() => _refresh();

  void _openDetail(DiaryEntry entry) =>
      Navigator.pushNamed(context, AppRoutes.entryDetail, arguments: entry);

  void _openForm() => Navigator.pushNamed(context, AppRoutes.entryForm);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis diarios'),
        actions: [
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
      drawer: const AppDrawer(currentRoute: AppRoutes.home),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.edit_note),
        label: const Text('Nueva entrada'),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return FutureBuilder<List<DiaryEntry>>(
      future: _entriesFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        // 1) Primera carga: indicador de progreso.
        if (isLoading && !snapshot.hasData) {
          return const LoadingView(message: 'Cargando tus diarios…');
        }

        // 2) Error: mensaje claro y botón de reintento (sin crash).
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ErrorView(
            message: error is AppException
                ? error.message
                : 'No pudimos cargar tus diarios.',
            onRetry: _refresh,
          );
        }

        final entries = snapshot.data ?? const <DiaryEntry>[];

        // 3) Sin datos: estado vacío con llamada a la acción.
        if (entries.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.7,
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  // La primera fila es el resumen con tus huellas.
                  itemCount: entries.length + 1,
                  separatorBuilder: (_, index) =>
                      SizedBox(height: index == 0 ? 16 : 10),
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

  final List<DiaryEntry> entries;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final places = entries.where((entry) => entry.hasLocation).length;
    final photos = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.imagePaths.length,
    );
    String plural(int n, String one, String many) =>
        '$n ${n == 1 ? one : many}';

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
            Text(
              'Tus huellas',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_greeting()}, ¿qué huella dejarás hoy?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 14),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
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

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delayMs = 60 * index.clamp(0, 8);
    final totalMs = 350 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOutCubic),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
