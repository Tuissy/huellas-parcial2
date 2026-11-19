// ARCHIVO: state_views.dart. Tres widgets reutilizables para los estados de
// carga, error y vacío del FutureBuilder. Los usan la lista, el detalle, el
// mapa y la búsqueda, así todas las pantallas se ven y se comportan igual.
import 'package:flutter/material.dart';

/// Indicador de carga con mensaje, usado mientras un `FutureBuilder`
/// espera datos de la base local.
class LoadingView extends StatelessWidget {
  // El mensaje es opcional; si no se pasa, se muestra 'Cargando…'.
  const LoadingView({super.key, this.message = 'Cargando…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    // Centramos una columna con el círculo de progreso y el texto debajo.
    // mainAxisSize.min hace que la columna ocupe solo el espacio que necesita.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Estado de error con opción de reintentar.
class ErrorView extends StatelessWidget {
  // message es obligatorio; onRetry e icon son opcionales. Por defecto se usa
  // el ícono de error.
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Ícono grande con el color de error del tema y el mensaje centrado.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            // if con el operador spread (...): el espacio y el botón
            // 'Reintentar' solo se agregan si la pantalla pasó onRetry.
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado vacío con ilustración, texto y acción opcional.
class EmptyView extends StatelessWidget {
  // Recibe ícono, título, mensaje y una acción opcional, por ejemplo el
  // botón 'Escribir mi primera entrada' de la lista.
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Diseño amable para cuando no hay datos: ícono dentro de un círculo,
    // título, explicación y, si existe, la acción.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Círculo con el color primario suave del tema y el ícono encima.
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            // Título y mensaje explicativo, centrados.
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            // La acción solo se agrega si existe, con un espacio encima.
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
