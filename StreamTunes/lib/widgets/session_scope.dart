import 'package:flutter/material.dart';

import '../view_models/session_view_model.dart';

/// Pone la sesión (quién soy y con qué bandas trabajo) en el árbol de widgets.
/// Igual que `ReproductorScope` y `LibraryScope`: sin prop-drilling.
class SessionScope extends InheritedNotifier<SessionViewModel> {
  const SessionScope({
    super.key,
    required SessionViewModel session,
    required super.child,
  }) : super(notifier: session);

  static SessionViewModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No se encontró SessionScope en el árbol de widgets');
    return scope!.notifier!;
  }

  /// `null` si no hay sesión en el árbol (por ejemplo en tests de widgets
  /// sueltos). Las vistas deben tolerarlo.
  static SessionViewModel? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionScope>()?.notifier;
  }

  /// Igual que [maybeOf] pero sin suscribir al widget: para leer la sesión
  /// dentro de un callback (un `onPressed`, por ejemplo) y no al construir.
  static SessionViewModel? maybeRead(BuildContext context) {
    return context.getInheritedWidgetOfExactType<SessionScope>()?.notifier;
  }
}
