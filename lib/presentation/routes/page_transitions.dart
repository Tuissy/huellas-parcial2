// ARCHIVO: page_transitions.dart. Transiciones personalizadas con
// PageRouteBuilder: cada tipo de pantalla tiene su propia animación de entrada
// y salida en lugar de la transición estándar de Material. El router
// (app_router.dart) decide cuál usar.
import 'package:flutter/material.dart';

/// Transición de desvanecido. Ideal para rutas con animaciones Hero: el
/// fondo aparece suavemente mientras la imagen "vuela" a su nueva posición.
class FadePageRoute<T> extends PageRouteBuilder<T> {
  // El constructor recibe el builder de la pantalla destino y parámetros
  // opcionales: settings (nombre y argumentos de la ruta), opaque y
  // barrierColor (los usa el visor de fotos para dejar ver la pantalla anterior
  // y oscurecer el fondo) y la duración, que por defecto es de 450 ms.
  FadePageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.opaque,
    super.barrierColor,
    Duration duration = const Duration(milliseconds: 450),
  }) : super(
         // Duración al entrar (la recibida) y al salir (350 ms, un poco más
         // rápida).
         transitionDuration: duration,
         reverseTransitionDuration: const Duration(milliseconds: 350),
         // pageBuilder construye la pantalla destino: simplemente llama al
         // builder que recibimos.
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         // transitionsBuilder define la animación. FadeTransition cambia la
         // opacidad de 0 a 1. CurvedAnimation suaviza el movimiento (arranca
         // rápido y frena al final) y usa otra curva al cerrar.
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
  // Solo necesita el builder y los settings; el resto de valores son fijos.
  SlideUpPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        // fullscreenDialog: true hace que Flutter la trate como un diálogo de
        // pantalla completa; por ejemplo, la AppBar muestra una X para cerrar
        // en vez de la flecha de atrás.
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Creamos una sola curva y la reutilizamos en las dos animaciones.
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          // Combinamos dos animaciones: la pantalla aparece (FadeTransition)
          // mientras sube desde un poco más abajo (SlideTransition). Offset(0,
          // 0.12) es un 12 % de su altura hacia abajo y termina en Offset.zero,
          // su posición normal.
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
