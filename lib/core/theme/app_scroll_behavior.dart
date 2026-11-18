import 'package:flutter/material.dart';

/// Comportamiento de desplazamiento de toda la app.
///
/// Desde Android 12, Material 3 "estira" el contenido al llegar al inicio
/// o al final de una lista, lo que deforma textos, fotos y el mapa. Aquí
/// se quita ese efecto: la página simplemente se detiene en el borde.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
