import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/mood.dart';
import 'mood_style.dart';

/// Etiquetas compartidas por los widgets `Hero`. La misma etiqueta en la
/// lista y en el detalle hace que la imagen "vuele" entre pantallas.
abstract final class HeroTags {
  static String entryImage(int? entryId, [int index = 0]) =>
      'entry-$entryId-image-$index';
}

/// Muestra una foto guardada en disco o, si no hay foto, un degradado con
/// el emoji del estado de ánimo. Nunca lanza excepción: si el archivo se
/// borró o está dañado, muestra un marcador de imagen rota.
class EntryImage extends StatelessWidget {
  const EntryImage({
    super.key,
    required this.path,
    required this.mood,
    this.fit = BoxFit.cover,
    this.emojiSize = 40,
    this.cacheWidth,
  });

  final String? path;
  final Mood mood;
  final BoxFit fit;
  final double emojiSize;

  /// Ancho de decodificación; reduce memoria en miniaturas.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final imagePath = path;
    if (imagePath == null) {
      return MoodPlaceholder(mood: mood, emojiSize: emojiSize);
    }

    return Image.file(
      File(imagePath),
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _BrokenImage(mood: mood),
    );
  }
}

/// Portada alternativa basada en el estado de ánimo.
class MoodPlaceholder extends StatelessWidget {
  const MoodPlaceholder({super.key, required this.mood, this.emojiSize = 40});

  final Mood mood;
  final double emojiSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: mood.gradient),
      child: Center(
        child: Text(mood.emoji, style: TextStyle(fontSize: emojiSize)),
      ),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage({required this.mood});

  final Mood mood;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: mood.gradient),
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 32,
        ),
      ),
    );
  }
}
