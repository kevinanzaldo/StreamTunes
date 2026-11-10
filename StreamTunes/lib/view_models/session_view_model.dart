import 'package:flutter/foundation.dart';

import '../models/band.dart';
import '../models/band_membership.dart';
import '../models/profile.dart';
import '../repositories/interfaces/auth_repository.dart';
import '../repositories/interfaces/band_repository.dart';
import '../repositories/interfaces/repository_failure.dart';

/// Si la app ya terminó de averiguar si hay una sesión guardada.
enum SessionStatus { restoring, ready }

/// Quién es la persona que usa la app y con qué bandas trabaja.
///
/// Reemplaza a `MockData.artistaLogueadoId` y al flag `esDuenoDelPerfil`: ser
/// "dueño" de un perfil pasa a ser `isMemberOf(band.id)`. Una sola cuenta por
/// persona; lo que cambia es su relación con las bandas (`BandMembership`).
///
/// Las operaciones devuelven `true` si salieron bien; si no, dejan el motivo en
/// [error] (mensaje listo para mostrar). Las confirmaciones que no son un
/// error (por ejemplo "revisá tu mail") quedan en [notice].
class SessionViewModel extends ChangeNotifier {
  SessionViewModel({
    required this._authRepository,
    required this._bandRepository,
  });

  final AuthRepository _authRepository;
  final BandRepository _bandRepository;

  SessionStatus _status = SessionStatus.restoring;
  Profile? _profile;
  List<BandMembership> _memberships = const [];
  String? _activeBandId;
  bool _isAdmin = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  bool _disposed = false;

  SessionStatus get status => _status;
  bool get isRestoring => _status == SessionStatus.restoring;

  /// La persona logueada, o `null` si es visitante.
  Profile? get profile => _profile;
  bool get isLoggedIn => _profile != null;
  bool get isAdmin => _isAdmin;

  /// Bandas donde la persona es miembro (cualquier estado), con su rol.
  List<BandMembership> get memberships => _memberships;
  bool get hasBand => _memberships.isNotEmpty;

  /// La banda con la que se está trabajando (la primera aprobada, o la primera
  /// que haya, hasta que se elija otra con [selectActiveBand]).
  BandMembership? get activeMembership {
    for (final membership in _memberships) {
      if (membership.band.id == _activeBandId) return membership;
    }
    return null;
  }

  Band? get activeBand => activeMembership?.band;

  /// `true` mientras una operación está en curso (evita dobles toques).
  bool get busy => _busy;

  String? get error => _error;
  String? get notice => _notice;

  bool isMemberOf(String bandId) =>
      _memberships.any((m) => m.band.id == bandId);

  bool isOwnerOf(String bandId) =>
      _memberships.any((m) => m.band.id == bandId && m.isOwner);

  void clearMessages() {
    if (_error == null && _notice == null) return;
    _error = null;
    _notice = null;
    _notify();
  }

  /// Recupera la sesión guardada de una visita anterior. Si falla (sin red,
  /// sesión vencida...) la app sigue como visitante.
  Future<void> restore() async {
    try {
      final profile = await _authRepository.restoreSession();
      if (profile != null) await _loadAccount(profile);
    } catch (_) {
      _clearAccount();
    }
    _status = SessionStatus.ready;
    _notify();
  }

  Future<bool> signIn({required String email, required String password}) async {
    if (_busy) return false;
    if (!_validEmail(email) || password.isEmpty) {
      return _fail('Ingresá tu email y tu contraseña.');
    }
    return _run(() async {
      final profile = await _authRepository.signIn(
        email: email,
        password: password,
      );
      await _loadAccount(profile);
      return true;
    });
  }

  /// Crea la cuenta. Si el proyecto exige confirmar el email no queda sesión
  /// iniciada: devuelve `true`, [isLoggedIn] es `false` y [notice] lo explica.
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_busy) return false;
    final name = displayName.trim();
    if (name.length < 2 || name.length > 50) {
      return _fail('El nombre tiene que tener entre 2 y 50 caracteres.');
    }
    if (!_validEmail(email)) return _fail('Ingresá un email válido.');
    if (password.length < 8) {
      return _fail('La contraseña tiene que tener al menos 8 caracteres.');
    }
    return _run(() async {
      final profile = await _authRepository.signUp(
        email: email,
        password: password,
        displayName: name,
      );
      if (profile == null) {
        _notice =
            'Te enviamos un mail para confirmar tu cuenta. Confirmalo y '
            'después iniciá sesión.';
      } else {
        await _loadAccount(profile);
      }
      return true;
    });
  }

  Future<void> signOut() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _notice = null;
    _notify();
    try {
      await _authRepository.signOut();
    } catch (_) {
      // Aunque falle el aviso al servidor, la persona sale de la app igual.
    }
    _clearAccount();
    _busy = false;
    _notify();
  }

  Future<bool> sendPasswordReset(String email) async {
    if (_busy) return false;
    if (!_validEmail(email)) return _fail('Ingresá un email válido.');
    return _run(() async {
      await _authRepository.sendPasswordReset(email);
      _notice =
          'Si el email está registrado, te enviamos un mail para '
          'cambiar la contraseña.';
      return true;
    });
  }

  /// Crea una banda (nace `pending`: no es pública hasta que un moderador la
  /// apruebe) y pasa a trabajar con ella.
  Future<bool> createBand({
    required String name,
    String genre = '',
    String location = '',
    String bio = '',
  }) async {
    if (_busy) return false;
    final profile = _profile;
    if (profile == null) return _fail('Iniciá sesión para crear una banda.');

    final cleanName = name.trim();
    final slug = Band.slugify(cleanName);
    if (cleanName.length < 2 || cleanName.length > 60 || slug.length < 2) {
      return _fail(
        'El nombre de la banda tiene que tener entre 2 y 60 '
        'caracteres, con letras o números.',
      );
    }
    return _run(() async {
      final created = await _bandRepository.createBand(
        Band(
          id: '',
          slug: slug,
          name: cleanName,
          genre: genre.trim(),
          location: location.trim(),
          bio: bio.trim(),
          createdBy: profile.id,
          createdAt: DateTime.now(),
        ),
      );
      _memberships = await _bandRepository.getMyMemberships(profile.id);
      _activeBandId = created.id;
      _notice = 'Banda creada. Te avisamos cuando un moderador la apruebe.';
      return true;
    });
  }

  /// Vuelve a pedir las bandas de la persona (por ejemplo, después de que un
  /// moderador aprobó una).
  Future<void> refreshMemberships() async {
    final profile = _profile;
    if (profile == null) return;
    try {
      _memberships = await _bandRepository.getMyMemberships(profile.id);
      _pickActiveBand();
      _notify();
    } catch (_) {
      // Se conserva la lista anterior.
    }
  }

  void selectActiveBand(String bandId) {
    if (!isMemberOf(bandId) || _activeBandId == bandId) return;
    _activeBandId = bandId;
    _notify();
  }

  // --- internos ------------------------------------------------------------

  Future<void> _loadAccount(Profile profile) async {
    _profile = profile;
    try {
      _isAdmin = await _authRepository.isAdmin();
    } catch (_) {
      _isAdmin = false;
    }
    try {
      _memberships = await _bandRepository.getMyMemberships(profile.id);
    } catch (_) {
      _memberships = const [];
    }
    _pickActiveBand();
  }

  void _pickActiveBand() {
    if (_memberships.isEmpty) {
      _activeBandId = null;
      return;
    }
    if (isMemberOf(_activeBandId ?? '')) return;
    final approved = _memberships.where((m) => m.band.isApproved);
    _activeBandId =
        (approved.isNotEmpty ? approved.first : _memberships.first).band.id;
  }

  void _clearAccount() {
    _profile = null;
    _memberships = const [];
    _activeBandId = null;
    _isAdmin = false;
  }

  /// Ejecuta [action] marcando [busy] y traduciendo los errores a [error].
  Future<bool> _run(Future<bool> Function() action) async {
    _busy = true;
    _error = null;
    _notice = null;
    _notify();
    try {
      final ok = await action();
      _busy = false;
      _notify();
      return ok;
    } on RepositoryFailure catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No pudimos completar la operación. Revisá tu conexión.';
    }
    _busy = false;
    _notify();
    return false;
  }

  bool _fail(String message) {
    _error = message;
    _notice = null;
    _notify();
    return false;
  }

  bool _validEmail(String email) {
    final value = email.trim();
    return value.contains('@') && value.contains('.') && value.length >= 5;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
