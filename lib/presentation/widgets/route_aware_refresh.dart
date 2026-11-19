// ARCHIVO: route_aware_refresh.dart. Concepto: RouteObserver / RouteAware para
// recargar al volver. Lo usan la lista, el detalle y el mapa de recuerdos.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../routes/app_router.dart';

/// Mixin que ejecuta [onReturnToScreen] cada vez que la pantalla vuelve a
/// quedar visible (cuando se cierra la ruta que estaba encima).
///
/// Así la lista y el detalle siempre muestran datos frescos tras crear,
/// editar o borrar una entrada, sin importar desde dónde se navegó.
mixin RouteAwareRefresh<T extends StatefulWidget> on State<T>
    implements RouteAware {
  // 'on State<T>' significa que este mixin solo se puede mezclar con un State,
  // e 'implements RouteAware' obliga a tener los cuatro métodos que llama el
  // RouteObserver. Cada pantalla solo implementa onReturnToScreen.
  // Guardamos la ruta a la que nos suscribimos para no suscribirnos dos veces.
  ModalRoute<void>? _subscribedRoute;

  /// Se llama al regresar a esta pantalla.
  void onReturnToScreen();

  // didChangeDependencies se ejecuta después de initState, cuando ya se puede
  // usar el context para obtener la ruta actual con ModalRoute.of. Si la ruta
  // cambió, cancelamos la suscripción anterior y nos suscribimos al
  // routeObserver de AppRouter con la nueva.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _subscribedRoute) {
      if (_subscribedRoute != null) AppRouter.routeObserver.unsubscribe(this);
      _subscribedRoute = route;
      AppRouter.routeObserver.subscribe(this, route);
    }
  }

  // Al destruir la pantalla cancelamos la suscripción, para que el observador
  // no siga llamando a un State que ya no existe.
  @override
  void dispose() {
    AppRouter.routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Concepto: microtarea para no recargar mientras el Navigator está ocupado
  // (corrección de un error real). didPopNext se llama cuando se cierra la
  // pantalla que estaba encima de esta.
  /// El Navigator invoca este método mientras actualiza su pila interna.
  /// La recarga se difiere a una microtarea para ejecutarse cuando el
  /// Navigator ya terminó: así un error en la recarga nunca puede dejar la
  /// navegación en un estado inconsistente.
  @override
  void didPopNext() {
    // scheduleMicrotask pone la recarga en cola para justo después de que el
    // Navigator termine. mounted comprueba que la pantalla siga existiendo
    // antes de recargar.
    scheduleMicrotask(() {
      if (mounted) onReturnToScreen();
    });
  }

  // Los otros tres métodos de RouteAware no se necesitan, pero como usamos
  // 'implements' hay que escribirlos; quedan vacíos.
  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}
