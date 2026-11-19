// ARCHIVO: entry_image.dart. Widgets para mostrar las fotos de una entrada de
// forma segura, y las etiquetas de los Hero.
import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/mood.dart';
import 'mood_style.dart';

/// Etiquetas compartidas por los widgets `Hero`. La misma etiqueta en la
/// lista y en el detalle hace que la imagen "vuele" entre pantallas.
abstract final class HeroTags {
  // Concepto: Hero, etiqueta compartida. La etiqueta combina el id de la
  // entrada y el índice de la foto para que sea única. La lista usa el
  // índice 0 (la portada) y el detalle y el visor usan el índice de cada
  // foto.
  static String entryImage(int? entryId, [int index = 0]) =>
      'entry-$entryId-image-$index';
}

/// Muestra una foto guardada en disco o, si no hay foto, un degradado con
/// el emoji del estado de ánimo. Nunca lanza excepción: si el archivo se
/// borró o está dañado, muestra un marcador de imagen rota.
class EntryImage extends StatelessWidget {
  // path puede ser null (entrada sin fotos). fit indica cómo se ajusta la
  // imagen al espacio y emojiSize el tamaño del emoji de respaldo.
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
    // Copiamos path a una variable local para que Dart la trate como String no
    // nulo después del if (promoción de tipos).
    final imagePath = path;
    // Sin foto: portada con el degradado y el emoji del ánimo.
    if (imagePath == null) {
      return MoodPlaceholder(mood: mood, emojiSize: emojiSize);
    }

    // Con foto: se lee el archivo desde el disco del teléfono. cacheWidth
    // reduce la memoria en las miniaturas, gaplessPlayback mantiene la imagen
    // anterior mientras carga la nueva (evita parpadeos) y errorBuilder muestra
    // la imagen rota en vez de fallar si el archivo ya no existe.
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
    // Caja con el degradado del ánimo (extensión MoodStyle) y el emoji
    // centrado.
    return DecoratedBox(
      decoration: BoxDecoration(gradient: mood.gradient),
      child: Center(
        child: Text(mood.emoji, style: TextStyle(fontSize: emojiSize)),
      ),
    );
  }
}

/// Marcador de imagen rota: el mismo degradado del ánimo con un ícono de
/// imagen dañada. Es privado porque solo lo usa EntryImage.
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
