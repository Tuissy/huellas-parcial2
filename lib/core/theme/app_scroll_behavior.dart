// Parte del tema global de la app (capa core).
import 'package:flutter/material.dart';

/// Comportamiento de desplazamiento de toda la app.
///
/// Desde Android 12, Material 3 "estira" el contenido al llegar al inicio
/// o al final de una lista, lo que deforma textos, fotos y el mapa. Aquí
/// se quita ese efecto: la página simplemente se detiene en el borde.
class AppScrollBehavior extends MaterialScrollBehavior {
  // Constructor const para poder usarlo como valor constante en
  // MaterialApp.
  const AppScrollBehavior();

  // Se sobrescribe el método que envuelve las listas con el indicador
  // de "fin de lista". Al devolver el hijo tal cual, no se dibuja ningún
  // efecto de estirado ni de brillo en los bordes.
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
