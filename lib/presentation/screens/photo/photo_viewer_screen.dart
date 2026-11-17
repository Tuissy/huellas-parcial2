import 'package:flutter/material.dart';

import '../../../domain/entities/mood.dart';
import '../../routes/app_routes.dart';
import '../../widgets/entry_image.dart';

/// Visor de fotos a pantalla completa con zoom (pellizcar) y Hero.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.args});

  final PhotoViewerArgs args;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.args.initialIndex,
  );
  late int _page = widget.args.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paths = widget.args.imagePaths;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('${_page + 1} de ${paths.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: paths.length,
        onPageChanged: (page) => setState(() => _page = page),
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Hero(
                tag: HeroTags.entryImage(widget.args.entryId, index),
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
