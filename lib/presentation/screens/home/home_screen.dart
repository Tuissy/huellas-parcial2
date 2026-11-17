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
      body: FutureBuilder<List<DiaryEntry>>(
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
                      title: 'Tu diario está vacío',
                      message:
                          'Escribe o dicta cómo fue tu día, añade una foto '
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
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _StaggeredEntrance(
                      index: index,
                      child: EntryCard(
                        entry: entries[index],
                        onTap: () => _openDetail(entries[index]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
