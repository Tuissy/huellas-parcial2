import 'package:flutter/widgets.dart';

import '../routes/app_router.dart';

/// Mixin que ejecuta [onReturnToScreen] cada vez que la pantalla vuelve a
/// quedar visible (cuando se cierra la ruta que estaba encima).
///
/// Así la lista y el detalle siempre muestran datos frescos tras crear,
/// editar o borrar una entrada, sin importar desde dónde se navegó.
mixin RouteAwareRefresh<T extends StatefulWidget> on State<T>
    implements RouteAware {
  ModalRoute<void>? _subscribedRoute;

  /// Se llama al regresar a esta pantalla.
  void onReturnToScreen();

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

  @override
  void dispose() {
    AppRouter.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => onReturnToScreen();

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}
