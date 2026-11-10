import 'package:flutter/widgets.dart';

import '../repositories/app_repositories.dart';

/// Pone los repositorios de la app en el árbol de widgets, para que las vistas
/// no los pasen por constructor (Regla 2: sin prop-drilling).
///
/// Los repositorios no cambian durante la sesión, por eso [of] no suscribe al
/// widget: se puede llamar desde `initState`.
///
/// Si no hay un `RepositoriesScope` arriba (típico en tests de widgets sueltos),
/// se usa un `AppRepositories.create()` compartido, que en modo demo es en memoria.
class RepositoriesScope extends InheritedWidget {
  const RepositoriesScope({
    super.key,
    required this.repositories,
    required super.child,
  });

  final AppRepositories repositories;

  static AppRepositories? _fallback;

  static AppRepositories of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RepositoriesScope>();
    return scope?.repositories ?? (_fallback ??= AppRepositories.create());
  }

  @override
  bool updateShouldNotify(RepositoriesScope oldWidget) =>
      repositories != oldWidget.repositories;
}
