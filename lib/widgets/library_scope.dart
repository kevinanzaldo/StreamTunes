import 'package:flutter/material.dart';

import '../view_models/library_view_model.dart';

class LibraryScope extends InheritedNotifier<LibraryViewModel> {
  const LibraryScope({
    super.key,
    required LibraryViewModel library,
    required super.child,
  }) : super(notifier: library);

  static LibraryViewModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LibraryScope>();
    assert(scope != null, 'No se encontró LibraryScope en el árbol de widgets');
    return scope!.notifier!;
  }

  static LibraryViewModel? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LibraryScope>()?.notifier;
  }
}
