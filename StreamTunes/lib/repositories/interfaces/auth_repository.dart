import '../../models/profile.dart';

/// Cuentas y sesión. Implementaciones: `FakeAuthRepository` (tests/demo) y
/// `SupabaseAuthRepository`.
///
/// Los errores esperables (credenciales incorrectas, email ya registrado...)
/// se lanzan como `RepositoryFailure` con mensaje en español.
abstract interface class AuthRepository {
  /// Perfil de la sesión guardada de una visita anterior, o `null` si no hay.
  Future<Profile?> restoreSession();

  Future<Profile> signIn({required String email, required String password});

  /// Crea la cuenta. Devuelve `null` si el proyecto exige confirmar el email:
  /// la cuenta existe pero todavía no hay sesión.
  Future<Profile?> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  /// ¿El usuario de la sesión actual es moderador del Colectivo?
  Future<bool> isAdmin();
}
