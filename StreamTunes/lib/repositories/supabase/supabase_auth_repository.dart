import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import '../interfaces/auth_repository.dart';
import '../interfaces/repository_failure.dart';

/// Implementación real sobre Supabase Auth + la tabla `profiles`.
///
/// `supabase_flutter` guarda y renueva la sesión solo; [restoreSession] la lee.
/// El perfil lo crea el trigger `on_auth_user_created` al registrarse (toma
/// `display_name` de los metadatos del alta).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  Future<Profile?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _fetchProfile(user.id);
  }

  @override
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const RepositoryFailure('No se pudo iniciar sesión.');
      }
      return await _fetchProfile(user.id);
    } on AuthException catch (e) {
      throw RepositoryFailure(_mensaje(e));
    }
  }

  @override
  Future<Profile?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
      final user = response.user;
      // Sin sesión = el proyecto exige confirmar el email antes de entrar.
      if (response.session == null || user == null) return null;
      return await _fetchProfile(user.id);
    } on AuthException catch (e) {
      throw RepositoryFailure(_mensaje(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw RepositoryFailure(_mensaje(e));
    }
  }

  @override
  Future<bool> isAdmin() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return false;
    // RLS: cada persona solo ve su propia fila de `app_admins`.
    final row = await _client
        .from('app_admins')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<Profile> _fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromJson(row);
  }

  String _mensaje(AuthException e) {
    final code = e.code.toString().toLowerCase();
    final text = e.message.toLowerCase();
    if (code == 'invalid_credentials' ||
        text.contains('invalid login credentials')) {
      return 'Email o contraseña incorrectos.';
    }
    if (code == 'email_not_confirmed' || text.contains('not confirmed')) {
      return 'Confirmá tu email antes de iniciar sesión.';
    }
    if (code == 'user_already_exists' || text.contains('already registered')) {
      return 'Ya existe una cuenta con ese email.';
    }
    if (code == 'weak_password') {
      return 'La contraseña es demasiado débil.';
    }
    if (code.contains('rate_limit') || text.contains('rate limit')) {
      return 'Demasiados intentos. Probá de nuevo en unos minutos.';
    }
    return 'No pudimos completar la operación. Intentá de nuevo.';
  }
}
