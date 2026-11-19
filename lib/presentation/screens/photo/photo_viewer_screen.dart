import 'package:flutter/material.dart';

import '../../../domain/entities/mood.dart';
import '../../routes/app_routes.dart';
import '../../widgets/entry_image.dart';

/// Visor de fotos a pantalla completa con zoom (pellizcar) y Hero.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.args});

  // Argumentos que llegan por la ruta con nombre: id de la entrada,
  // rutas de las fotos y cuál se abre primero.
  final PhotoViewerArgs args;

  // Crea el objeto State, que guarda lo que cambia en esta pantalla.
  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

/// Estado del visor: sabe en qué foto está el usuario.
class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  // Controlador del PageView, que arranca en la foto que se tocó. Es
  // late para poder usar widget al crearlo.
  late final PageController _controller = PageController(
    initialPage: widget.args.initialIndex,
  );
  // Página actual, para mostrar "2 de 4" en el título.
  late int _page = widget.args.initialIndex;

  // Al cerrar la pantalla se libera el controlador para no gastar
  // memoria.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Pantalla negra con las fotos que se pasan deslizando de lado.
  @override
  Widget build(BuildContext context) {
    // Rutas de las fotos a mostrar.
    final paths = widget.args.imagePaths;
    // Fondo negro; el AppBar es transparente y queda encima de la foto
    // gracias a extendBodyBehindAppBar.
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        // Contador de la foto actual, por ejemplo "1 de 3".
        title: Text('${_page + 1} de ${paths.length}'),
      ),
      // PageView: se desliza de lado para pasar de una foto a otra. Al
      // cambiar de página, setState actualiza el contador del título.
      body: PageView.builder(
        controller: _controller,
        itemCount: paths.length,
        onPageChanged: (page) => setState(() => _page = page),
        // Un toque sobre la foto cierra el visor y vuelve al detalle.
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => Navigator.pop(context),
          // InteractiveViewer para hacer zoom con dos dedos (de 1x a 5x)
          // y mover la foto ampliada.
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              // Hero: la foto "vuela" con animación desde la pantalla de
              // detalle, porque ambas usan la misma etiqueta (tag).
              child: Hero(
                tag: HeroTags.entryImage(widget.args.entryId, index),
                // Foto completa sin recortar (BoxFit.contain). El ánimo
                // neutral solo da color al aviso si la foto no carga.
                child: EntryImage(
                  path: paths[index],
                  mood: Mood.neutral,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
