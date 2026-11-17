import 'package:flutter/material.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/diary_entry.dart';
import '../../../domain/repositories/diary_repository.dart';
import '../../widgets/entry_card.dart';
import '../../widgets/state_views.dart';

/// Búsqueda de entradas por título o contenido (consulta SQL con LIKE).
class EntrySearchDelegate extends SearchDelegate<void> {
  EntrySearchDelegate({required this.repository, required this.onOpen})
    : super(searchFieldLabel: 'Buscar en mis diarios');

  final DiaryRepository repository;
  final void Function(DiaryEntry entry) onOpen;

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Limpiar',
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => const BackButton();

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return const EmptyView(
        icon: Icons.search,
        title: 'Busca un recuerdo',
        message: 'Escribe una palabra del título o del contenido.',
      );
    }
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    return FutureBuilder<List<DiaryEntry>>(
      // La clave fuerza un nuevo FutureBuilder por cada texto buscado.
      key: ValueKey(query),
      future: repository.search(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Buscando…');
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ErrorView(
            message: error is AppException ? error.message : 'Error al buscar.',
          );
        }
        final results = snapshot.data ?? const [];
        if (results.isEmpty) {
          return EmptyView(
            icon: Icons.search_off,
            title: 'Sin resultados',
            message: 'No encontramos entradas con "$query".',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => EntryCard(
            entry: results[index],
            onTap: () => onOpen(results[index]),
          ),
        );
      },
    );
  }
}
