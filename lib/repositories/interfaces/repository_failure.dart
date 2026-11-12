/// Error "esperable" de un repositorio, con un mensaje listo para mostrarle
/// al usuario (por ejemplo "Email o contraseña incorrectos."). Cada
/// implementación traduce sus errores técnicos a esto, así los view models no
/// dependen de Supabase.
class RepositoryFailure implements Exception {
  const RepositoryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
