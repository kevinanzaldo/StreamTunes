import '../../models/profile.dart';
import '../interfaces/auth_repository.dart';
import '../interfaces/repository_failure.dart';

class _FakeUser {
  _FakeUser({
    required this.profile,
    required this.email,
    required this.password,
    this.isAdmin = false,
  });

  final Profile profile;
  final String email;
  final String password;
  final bool isAdmin;
}

/// Cuentas en memoria (tests y modo demo). La sesión vive solo en la instancia.
///
/// Usuarios de demo, todos con la contraseña [demoPassword]:
/// - `ana@streamtunes.test`: dueña de "Los Subterráneos" (`artist_1`).
/// - `beto@streamtunes.test`: dueño de "Banda Fractal" (`artist_2`).
/// - `caro@streamtunes.test`: oyente, sin banda.
/// - `admin@streamtunes.test`: moderadora del Colectivo.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository() {
    final now = DateTime(2026, 1, 1);
    _users.addAll([
      _FakeUser(
        profile: Profile(
          id: 'user_artist_1',
          displayName: 'Ana Quiroga',
          createdAt: now,
        ),
        email: 'ana@streamtunes.test',
        password: demoPassword,
      ),
      _FakeUser(
        profile: Profile(
          id: 'user_artist_2',
          displayName: 'Beto Salinas',
          createdAt: now,
        ),
        email: 'beto@streamtunes.test',
        password: demoPassword,
      ),
      _FakeUser(
        profile: Profile(
          id: 'user_caro',
          displayName: 'Caro Funes',
          createdAt: now,
        ),
        email: 'caro@streamtunes.test',
        password: demoPassword,
      ),
      _FakeUser(
        profile: Profile(
          id: 'user_admin',
          displayName: 'Admin Colectivo',
          createdAt: now,
        ),
        email: 'admin@streamtunes.test',
        password: demoPassword,
        isAdmin: true,
      ),
    ]);
  }

  static const String demoPassword = 'Test1234!';

  final List<_FakeUser> _users = [];
  _FakeUser? _current;
  int _newUsers = 0;

  String _normalize(String email) => email.trim().toLowerCase();

  _FakeUser? _byEmail(String email) {
    final wanted = _normalize(email);
    for (final user in _users) {
      if (user.email == wanted) return user;
    }
    return null;
  }

  @override
  Future<Profile?> restoreSession() async => _current?.profile;

  @override
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    final user = _byEmail(email);
    if (user == null || user.password != password) {
      throw const RepositoryFailure('Email o contraseña incorrectos.');
    }
    _current = user;
    return user.profile;
  }

  @override
  Future<Profile?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_byEmail(email) != null) {
      throw const RepositoryFailure('Ya existe una cuenta con ese email.');
    }
    _newUsers++;
    final user = _FakeUser(
      profile: Profile(
        id: 'user_new_$_newUsers',
        displayName: displayName.trim(),
        createdAt: DateTime.now(),
      ),
      email: _normalize(email),
      password: password,
    );
    _users.add(user);
    _current = user;
    return user.profile;
  }

  @override
  Future<void> signOut() async {
    _current = null;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    // En la demo no se envía ningún mail.
  }

  @override
  Future<bool> isAdmin() async => _current?.isAdmin ?? false;
}
