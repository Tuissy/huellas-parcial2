// ARCHIVO: mood_style.dart. Colores y degradados de cada estado de ánimo.
import 'package:flutter/material.dart';

import '../../domain/entities/mood.dart';

/// Estilos visuales de cada [Mood]. Viven en la capa de presentación para
/// que el dominio no dependa de Flutter.
extension MoodStyle on Mood {
  // Concepto: extensión (extension). Agrega getters al enum Mood sin
  // modificarlo: en los widgets escribimos mood.color, pero el dominio sigue
  // siendo Dart puro, sin importar Flutter.
  // Color de cada ánimo con un switch expression: si se agrega un ánimo
  // nuevo, el compilador obliga a asignarle un color.
  Color get color => switch (this) {
    Mood.great => const Color(0xFFF4A261),
    Mood.good => const Color(0xFF2A9D8F),
    Mood.neutral => const Color(0xFF8D99AE),
    Mood.sad => const Color(0xFF457B9D),
    Mood.stressed => const Color(0xFFE76F51),
  };

  /// Degradado usado como portada cuando la entrada no tiene foto.
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    // Va del color del ánimo a una versión un 35 % más oscura (Color.lerp lo
    // mezcla con negro), en diagonal.
    colors: [color, Color.lerp(color, Colors.black, 0.35)!],
  );
}
