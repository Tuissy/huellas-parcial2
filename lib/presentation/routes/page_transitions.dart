import 'package:flutter/material.dart';

/// Transición de desvanecido. Ideal para rutas con animaciones Hero: el
/// fondo aparece suavemente mientras la imagen "vuela" a su nueva posición.
class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.opaque,
    super.barrierColor,
    Duration duration = const Duration(milliseconds: 450),
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: const Duration(milliseconds: 350),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return FadeTransition(
             opacity: CurvedAnimation(
               parent: animation,
               curve: Curves.easeOutCubic,
               reverseCurve: Curves.easeInCubic,
             ),
             child: child,
           );
         },
       );
}

/// Transición que desliza la pantalla desde abajo, usada para el
/// formulario de creación (comunica "nueva tarea encima de la actual").
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  SlideUpPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}
