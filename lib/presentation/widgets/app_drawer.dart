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
    final selectedIndex = _destinations.indexWhere(
      (destination) => destination.route == currentRoute,
    );

    return NavigationDrawer(
      selectedIndex: selectedIndex < 0 ? null : selectedIndex,
      onDestinationSelected: (index) =>
          _navigate(context, _destinations[index].route),
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
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
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            shape: const StadiumBorder(),
            leading: const Icon(Icons.edit_note),
            title: const Text('Nueva entrada'),
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
        ),
      ],
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
