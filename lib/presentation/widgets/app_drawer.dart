import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

/// Menú lateral principal.
///
/// Resalta la sección actual para que el usuario siempre sepa dónde está y
/// mantiene la pila de navegación limpia: las secciones se abren encima de
/// la lista principal y nunca se apilan unas sobre otras.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.currentRoute});

  final String currentRoute;

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

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          children: [
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
            for (final destination in _destinations)
              _DrawerTile(
                icon: destination.route == currentRoute
                    ? destination.selectedIcon
                    : destination.icon,
                label: destination.label,
                selected: destination.route == currentRoute,
                onTap: () => _navigate(context, destination.route),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),
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

  void _navigate(BuildContext context, String route) {
    Navigator.pop(context); // Cierra el Drawer.
    if (route == currentRoute) return;

    if (route == AppRoutes.home) {
      Navigator.popUntil(context, ModalRoute.withName(AppRoutes.home));
    } else {
      // Pila resultante: [Inicio, Sección]. "Atrás" siempre vuelve a Inicio.
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        ModalRoute.withName(AppRoutes.home),
      );
    }
  }
}

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
