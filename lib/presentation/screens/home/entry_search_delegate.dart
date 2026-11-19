import 'package:flutter/material.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/diary_entry.dart';
import '../../../domain/repositories/diary_repository.dart';
import '../../widgets/entry_card.dart';
import '../../widgets/state_views.dart';

/// Búsqueda de entradas por título o contenido (consulta SQL con LIKE).
class EntrySearchDelegate extends SearchDelegate<void> {
  // Recibe el repositorio y la acción para abrir un resultado. Con
  // super se cambia el texto de ayuda del campo de búsqueda.
  EntrySearchDelegate({required this.repository, required this.onOpen})
    : super(searchFieldLabel: 'Buscar en mis diarios');

  // Repositorio del dominio donde se hace la búsqueda.
  final DiaryRepository repository;
  // Qué hacer al tocar un resultado; lo decide la pantalla principal
  // (abrir el detalle de la entrada).
  final void Function(DiaryEntry entry) onOpen;

  // Botones a la derecha del campo: la X para borrar el texto escrito.
  // Solo aparece cuando hay algo escrito.
  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Limpiar',
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
  ];

  // Botón de la izquierda: flecha para cerrar la búsqueda y volver.
  @override
  Widget buildLeading(BuildContext context) => const BackButton();

  // Resultados al confirmar la búsqueda con el teclado: la misma lista.
  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  // Sugerencias mientras se escribe: con el campo vacío se muestra una
  // ayuda; con texto se busca en vivo en cada letra.
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

  /// Lista de resultados con FutureBuilder y sus estados: cargando,
  /// error, sin resultados y datos.
  Widget _buildList(BuildContext context) {
    return FutureBuilder<List<DiaryEntry>>(
      // La clave fuerza un nuevo FutureBuilder por cada texto buscado.
      key: ValueKey(query),
      // Consulta en SQLite por título o contenido.
      future: repository.search(query),
      builder: (context, snapshot) {
        // Cargando: CircularProgressIndicator con el texto "Buscando".
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Buscando…');
        }
        // Error: mensaje amigable si es una AppException, si no genérico.
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ErrorView(
            message: error is AppException ? error.message : 'Error al buscar.',
          );
        }
        // Sin resultados: se avisa qué palabra no se encontró.
        final results = snapshot.data ?? const [];
        if (results.isEmpty) {
          return EmptyView(
            icon: Icons.search_off,
            title: 'Sin resultados',
            message: 'No encontramos entradas con "$query".',
          );
        }
        // Con datos: la misma tarjeta de la pantalla principal. Al
        // tocarla se ejecuta onOpen para abrir el detalle.
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
