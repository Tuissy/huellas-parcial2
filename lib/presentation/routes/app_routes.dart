// ARCHIVO: app_routes.dart (capa de presentación, carpeta routes). Aquí
// están los nombres de todas las rutas de la app. Es la base de las rutas con
// nombre: en lugar de crear cada pantalla a mano, navegamos con
// Navigator.pushNamed usando estas constantes.
/// Nombres de las rutas (Named Routes) de la aplicación.
///
/// Centralizarlos evita errores de escritura y documenta el mapa de
/// navegación en un solo lugar.
abstract final class AppRoutes {
  // La clase es 'abstract final': no se puede instanciar ni heredar, solo sirve
  // para agrupar constantes.
  // Cada constante es la dirección de una pantalla. '/lock' es el bloqueo
  // biométrico y '/' es la lista principal (Inicio). El detalle, el formulario
  // y el visor de fotos empiezan con '/entry' porque todos trabajan sobre una
  // entrada del diario.
  static const String lock = '/lock';
  static const String home = '/';
  static const String entryDetail = '/entry';
  static const String entryForm = '/entry/form';
  static const String photoViewer = '/entry/photo';
  // Secciones a las que se llega desde el menú lateral (Drawer): mapa de
  // recuerdos, ajustes y acerca de.
  static const String map = '/map';
  static const String settings = '/settings';
  static const String about = '/about';
}

/// Argumentos de la ruta [AppRoutes.photoViewer].
class PhotoViewerArgs {
  // Una ruta con nombre recibe un solo argumento de tipo Object, así que
  // agrupamos en esta clase todo lo que necesita el visor de fotos. El router
  // comprueba con 'is PhotoViewerArgs' que llegó el tipo correcto.
  // initialIndex vale 0 si no se indica.
  const PhotoViewerArgs({
    required this.entryId,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  // entryId sirve para armar la etiqueta del Hero, imagePaths son las rutas de
  // las fotos en disco e initialIndex dice qué foto se muestra primero.
  final int entryId;
  final List<String> imagePaths;
  final int initialIndex;
}
