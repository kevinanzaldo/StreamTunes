import 'package:flutter/material.dart';

import '../widgets/session_scope.dart';
import 'login_view.dart';

/// Protege una pantalla que necesita sesión iniciada.
///
/// - Sin `SessionScope` en el árbol (tests sueltos) deja pasar.
/// - Mientras se recupera la sesión guardada muestra un indicador de carga.
/// - Sin sesión muestra el formulario de ingreso con [message]; al entrar,
///   la pantalla protegida aparece sola en el mismo lugar (la persona "vuelve"
///   adonde estaba, sin cambiar de pestaña).
class SessionGate extends StatelessWidget {
  const SessionGate({
    super.key,
    required this.title,
    required this.message,
    required this.builder,
  });

  /// Título de la barra mientras se pide el ingreso.
  final String title;

  /// Por qué hace falta iniciar sesión (se muestra arriba del formulario).
  final String message;

  /// Pantalla real, solo con sesión iniciada.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.maybeOf(context);
    if (session == null) return builder(context);

    if (session.isRestoring) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!session.isLoggedIn) return LoginView(title: title, message: message);
    return builder(context);
  }
}
