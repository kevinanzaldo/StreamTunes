import 'package:flutter/material.dart';

import '../view_models/reproductor_view_model.dart';

class ReproductorScope extends InheritedNotifier<ReproductorViewModel> {
  const ReproductorScope({
    super.key,
    required ReproductorViewModel reproductor,
    required super.child,
  }) : super(notifier: reproductor);

  static ReproductorViewModel of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ReproductorScope>();
    assert(
      scope != null,
      'No se encontró ReproductorScope en el árbol de widgets',
    );
    return scope!.notifier!;
  }

  static ReproductorViewModel? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ReproductorScope>()
        ?.notifier;
  }
}
