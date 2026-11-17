/// Nombres de las rutas (Named Routes) de la aplicación.
///
/// Centralizarlos evita errores de escritura y documenta el mapa de
/// navegación en un solo lugar.
abstract final class AppRoutes {
  static const String lock = '/lock';
  static const String home = '/';
  static const String entryDetail = '/entry';
  static const String entryForm = '/entry/form';
  static const String photoViewer = '/entry/photo';
  static const String map = '/map';
  static const String settings = '/settings';
  static const String about = '/about';
}

/// Argumentos de la ruta [AppRoutes.photoViewer].
class PhotoViewerArgs {
  const PhotoViewerArgs({
    required this.entryId,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  final int entryId;
  final List<String> imagePaths;
  final int initialIndex;
}
