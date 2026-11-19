import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../widgets/app_drawer.dart';

/// Información de la app: qué problema resuelve y qué tecnologías usa.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Funciones principales de la app guardadas como registros (records
  // de Dart 3): ícono, título y descripción. Es const porque no cambia.
  static const _features = [
    (
      Icons.photo_camera_outlined,
      'Cámara y galería',
      'Ilustra tu día con hasta 4 fotos.',
    ),
    (
      Icons.mic_none,
      'Dictado por voz',
      'Captura audio del micrófono y lo convierte en texto.',
    ),
    (
      Icons.place_outlined,
      'GPS y mapas',
      'Guarda dónde escribiste y ábrelo en Google Maps.',
    ),
    (
      Icons.fingerprint,
      'Bloqueo biométrico',
      'Protege tu diario con huella, rostro o PIN.',
    ),
    (
      Icons.storage_outlined,
      'SQLite local',
      'Todo se guarda en tu dispositivo, sin internet.',
    ),
  ];

  // Pantalla estática (StatelessWidget): Scaffold con AppBar, Drawer y
  // una lista desplazable con la información.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de')),
      // Menú lateral compartido, con "Acerca de" como opción actual.
      drawer: const AppDrawer(currentRoute: AppRoutes.about),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Logo: ícono de una huella dentro de un círculo.
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.pets,
                size: 44,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Nombre de la app y su versión.
          Text(
            'Huellas',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          Text(
            'Diario personal multimedia · v1.0.0',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          // Tarjeta que explica qué problema resuelve la app.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Qué problema resuelve?',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Llevar un diario cuesta trabajo: escribir en el teléfono es lento '
                    'y con el tiempo olvidamos dónde y cómo vivimos cada momento. '
                    'Huellas permite registrar el día en segundos —dictando en lugar '
                    'de teclear—, acompañarlo de fotos y guardar automáticamente la '
                    'ubicación, todo de forma privada y sin conexión.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Un ListTile por cada función. El for dentro de la lista
          // desarma cada registro en ícono, título y descripción.
          for (final (icon, title, subtitle) in _features)
            ListTile(
              leading: Icon(icon, color: theme.colorScheme.primary),
              title: Text(title),
              subtitle: Text(subtitle),
            ),
          const SizedBox(height: 12),
          // Crédito de los mapas, que pide la licencia de OpenStreetMap.
          Text(
            'Mapas © colaboradores de OpenStreetMap.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
