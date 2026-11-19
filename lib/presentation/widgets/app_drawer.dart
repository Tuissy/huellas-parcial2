// ARCHIVO: app_drawer.dart. Concepto: Drawer con pushNamedAndRemoveUntil para
// mantener la pila limpia. Cada sección principal muestra este mismo menú.
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

/// Menú lateral principal.
///
/// Resalta la sección actual para que el usuario siempre sepa dónde está y
/// mantiene la pila de navegación limpia: las secciones se abren encima de
/// la lista principal y nunca se apilan unas sobre otras.
class AppDrawer extends StatelessWidget {
  // currentRoute es el nombre de la ruta de la pantalla que muestra el menú;
  // sirve para resaltar la opción actual.
  const AppDrawer({super.key, required this.currentRoute});

  final String currentRoute;

  // Lista constante con las secciones del menú: ruta, texto, ícono normal e
  // ícono relleno para cuando está seleccionada. Para agregar una sección
  // basta con añadir un elemento aquí.
  static const _destinations = <_DrawerDestination>[
    _DrawerDestination(
      AppRoutes.home,
      'Mis diarios',
      Icons.auto_stories_outlined,
      Icons.auto_stories,
    ),
    _DrawerDestination(
      AppRoutes.map,
      'Mapa de recuerdos',
      Icons.map_outlined,
      Icons.map,
    ),
    _DrawerDestination(
      AppRoutes.settings,
      'Ajustes',
      Icons.settings_outlined,
      Icons.settings,
    ),
    _DrawerDestination(
      AppRoutes.about,
      'Acerca de',
      Icons.info_outline,
      Icons.info,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Drawer con SafeArea para no quedar debajo de la barra de estado. ListView
    // permite desplazar el menú si no cabe.
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          children: [
            // Cabecera con degradado de los colores del tema, el ícono de
            // huella, el nombre de la app y su descripción.
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pets, color: Colors.white, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'Huellas',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Tu diario personal con fotos, voz y lugares',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            // Un _DrawerTile por cada sección. Si es la pantalla actual, usa
            // el ícono relleno y queda resaltada.
            for (final destination in _destinations)
              _DrawerTile(
                icon: destination.route == currentRoute
                    ? destination.selectedIcon
                    : destination.icon,
                label: destination.label,
                selected: destination.route == currentRoute,
                onTap: () => _navigate(context, destination.route),
              ),
            // Separador entre las secciones y la acción 'Nueva entrada'.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),
            // Atajo para escribir una entrada desde cualquier sección: primero
            // se cierra el Drawer y luego se abre el formulario, quitando las
            // pantallas que haya entre él y la lista principal.
            _DrawerTile(
              icon: Icons.edit_note,
              label: 'Nueva entrada',
              selected: false,
              onTap: () {
                Navigator.pop(context);
                // Al guardar, el formulario regresa directamente a la lista.
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.entryForm,
                  ModalRoute.withName(AppRoutes.home),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Navega a una sección del menú manteniendo limpia la pila de pantallas.
  void _navigate(BuildContext context, String route) {
    Navigator.pop(context); // Cierra el Drawer.
    // Si ya estamos en esa sección, basta con cerrar el menú.
    if (route == currentRoute) return;

    // Para ir a Inicio no abrimos una pantalla nueva: cerramos todas las de
    // encima hasta llegar a la lista que ya existe (popUntil).
    if (route == AppRoutes.home) {
      Navigator.popUntil(context, ModalRoute.withName(AppRoutes.home));
    } else {
      // Pila resultante: [Inicio, Sección]. "Atrás" siempre vuelve a Inicio.
      // pushNamedAndRemoveUntil abre la sección y quita todas las rutas que
      // haya encima de Inicio, así las secciones nunca se apilan unas sobre
      // otras.
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        ModalRoute.withName(AppRoutes.home),
      );
    }
  }
}

/// Datos de una opción del menú. Es inmutable y tiene constructor const, por
/// eso la lista de arriba puede ser constante.
class _DrawerDestination {
  const _DrawerDestination(
    this.route,
    this.label,
    this.icon,
    this.selectedIcon,
  );

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Opción del menú. `ListTile` recorta con elipsis los textos largos, así
/// el menú no se desborda con tamaños de letra grandes (accesibilidad).
class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // ListTile con forma de píldora (StadiumBorder). Cuando selected es true,
    // usa los colores secondaryContainer del tema para resaltar la opción.
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: const StadiumBorder(),
        selected: selected,
        selectedColor: scheme.onSecondaryContainer,
        selectedTileColor: scheme.secondaryContainer,
        leading: Icon(icon),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: onTap,
      ),
    );
  }
}
