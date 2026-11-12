import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/profile.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/widgets/session_scope.dart';

/// Proyecto que exige confirmar el email: el alta no deja sesión iniciada.
class _ConfirmEmailAuthRepository extends FakeAuthRepository {
  @override
  Future<Profile?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async => null;
}

/// Restaurar la sesión tarda un poco (para probar el uso tras `dispose`).
class _SlowAuthRepository extends FakeAuthRepository {
  @override
  Future<Profile?> restoreSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return super.restoreSession();
  }
}

const _ana = 'ana@streamtunes.test';
const _caro = 'caro@streamtunes.test';
const _admin = 'admin@streamtunes.test';
const _pass = FakeAuthRepository.demoPassword;

SessionViewModel _crear({FakeAuthRepository? auth}) {
  final vm = SessionViewModel(
    authRepository: auth ?? FakeAuthRepository(),
    bandRepository: FakeBandRepository(),
  );
  addTearDown(vm.dispose);
  return vm;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'SessionViewModel: restore() sin sesión guardada deja un visitante',
    () async {
      final vm = _crear();

      expect(vm.isRestoring, isTrue);
      await vm.restore();

      expect(vm.status, SessionStatus.ready);
      expect(vm.isLoggedIn, isFalse);
      expect(vm.profile, isNull);
      expect(vm.hasBand, isFalse);
      expect(vm.isMemberOf('artist_1'), isFalse);
    },
  );

  test('SessionViewModel: una dueña ve su banda como activa y solo es miembro de esa', () async {
    final vm = _crear();
    const suya = 'artist_1';
    const ajena = 'artist_2';

    expect(await vm.signIn(email: _ana, password: _pass), isTrue);

    expect(vm.isLoggedIn, isTrue);
    expect(vm.profile?.displayName, 'Ana Quiroga');
    expect(vm.isMemberOf(suya), isTrue);
    expect(vm.isMemberOf(ajena), isFalse);
    expect(vm.activeBand?.id, suya);
    expect(vm.isAdmin, isFalse);
    expect(vm.error, isNull);
  });

  test(
    'SessionViewModel: un oyente no tiene banda y la moderadora es admin',
    () async {
      final oyente = _crear();
      expect(await oyente.signIn(email: _caro, password: _pass), isTrue);
      expect(oyente.isLoggedIn, isTrue);
      expect(oyente.hasBand, isFalse);
      expect(oyente.activeBand, isNull);
      expect(oyente.isAdmin, isFalse);

      final admin = _crear();
      expect(await admin.signIn(email: _admin, password: _pass), isTrue);
      expect(admin.isAdmin, isTrue);
    },
  );

  test('SessionViewModel: credenciales incorrectas informan el error y no inician sesión', () async {
    final vm = _crear();

    expect(await vm.signIn(email: _ana, password: 'incorrecta'), isFalse);
    expect(vm.isLoggedIn, isFalse);
    expect(vm.error, 'Email o contraseña incorrectos.');
    expect(vm.busy, isFalse);

    // Campos vacíos: se rechaza antes de llamar al repositorio.
    expect(await vm.signIn(email: '', password: ''), isFalse);
    expect(vm.error, contains('email'));
  });

  test('SessionViewModel: no inicia sesión dos veces si se toca el botón en simultáneo', () async {
    final vm = _crear();

    final resultados = await Future.wait([
      vm.signIn(email: _ana, password: _pass),
      vm.signIn(email: _ana, password: _pass),
    ]);

    expect(resultados, equals([true, false]));
    expect(vm.isLoggedIn, isTrue);
  });

  test(
    'SessionViewModel: signUp valida los datos y rechaza emails repetidos',
    () async {
      final vm = _crear();

      expect(
        await vm.signUp(
          email: 'nuevo@mail.com',
          password: '123',
          displayName: 'Nico',
        ),
        isFalse,
      );
      expect(vm.error, contains('8 caracteres'));

      expect(
        await vm.signUp(
          email: 'nuevo@mail.com',
          password: 'Clave1234',
          displayName: 'N',
        ),
        isFalse,
      );
      expect(vm.error, contains('nombre'));

      expect(
        await vm.signUp(
          email: _ana,
          password: 'Clave1234',
          displayName: 'Otra Ana',
        ),
        isFalse,
      );
      expect(vm.error, 'Ya existe una cuenta con ese email.');
      expect(vm.isLoggedIn, isFalse);
    },
  );

  test(
    'SessionViewModel: signUp crea la cuenta e inicia sesión sin bandas',
    () async {
      final vm = _crear();

      final ok = await vm.signUp(
        email: 'nico@mail.com',
        password: 'Clave1234',
        displayName: '  Nico Paz  ',
      );

      expect(ok, isTrue);
      expect(vm.isLoggedIn, isTrue);
      expect(vm.profile?.displayName, 'Nico Paz');
      expect(vm.hasBand, isFalse);
      expect(vm.error, isNull);
    },
  );

  test('SessionViewModel: si hay que confirmar el email no queda sesión pero avisa', () async {
    final vm = _crear(auth: _ConfirmEmailAuthRepository());

    final ok = await vm.signUp(
      email: 'nico@mail.com',
      password: 'Clave1234',
      displayName: 'Nico Paz',
    );

    expect(ok, isTrue);
    expect(vm.isLoggedIn, isFalse);
    expect(vm.notice, isNotNull);
    expect(vm.error, isNull);
  });

  test('SessionViewModel: signOut limpia perfil, bandas y permisos', () async {
    final vm = _crear();
    await vm.signIn(email: _admin, password: _pass);
    expect(vm.isAdmin, isTrue);

    await vm.signOut();

    expect(vm.isLoggedIn, isFalse);
    expect(vm.profile, isNull);
    expect(vm.isAdmin, isFalse);
    expect(vm.hasBand, isFalse);
    expect(vm.activeBand, isNull);

    // Y la sesión no se recupera sola después de salir.
    final otro = SessionViewModel(
      authRepository: FakeAuthRepository(),
      bandRepository: FakeBandRepository(),
    );
    addTearDown(otro.dispose);
    await otro.restore();
    expect(otro.isLoggedIn, isFalse);
  });

  test(
    'SessionViewModel: crear una banda la deja pendiente y la pone como activa',
    () async {
      final vm = _crear();
      await vm.signIn(email: _caro, password: _pass);

      final ok = await vm.createBand(
        name: '  Los Nuevos  ',
        genre: 'Rock',
        location: 'Mendoza',
      );

      expect(ok, isTrue);
      expect(vm.hasBand, isTrue);
      expect(vm.activeBand?.name, 'Los Nuevos');
      expect(vm.activeBand?.status, BandStatus.pending);
      expect(vm.notice, isNotNull);
    },
  );

  test('SessionViewModel: no deja crear bandas a un visitante, con nombre inválido o repetido', () async {
    final vm = _crear();
    expect(await vm.createBand(name: 'Los Nuevos'), isFalse);
    expect(vm.error, contains('Iniciá sesión'));

    await vm.signIn(email: _caro, password: _pass);

    expect(await vm.createBand(name: '!'), isFalse);
    expect(vm.error, contains('nombre de la banda'));

    expect(await vm.createBand(name: 'Los Subterráneos'), isFalse);
    expect(vm.error, 'Ya existe una banda con ese nombre.');
    expect(vm.hasBand, isFalse);
  });

  test('SessionViewModel: selectActiveBand cambia entre mis bandas e ignora las ajenas', () async {
    final vm = _crear();
    await vm.signIn(email: _ana, password: _pass);
    const primera = 'artist_1';

    await vm.createBand(name: 'Segunda Banda');
    final segunda = vm.activeBand!.id;
    expect(segunda, isNot(primera));
    expect(vm.memberships, hasLength(2));

    vm.selectActiveBand(primera);
    expect(vm.activeBand?.id, primera);

    vm.selectActiveBand('artist_2');
    expect(vm.activeBand?.id, primera);
  });

  test('SessionViewModel: no notifica después de dispose si restore() termina tarde', () async {
    final vm = SessionViewModel(
      authRepository: _SlowAuthRepository(),
      bandRepository: FakeBandRepository(),
    );

    final restore = vm.restore();
    vm.dispose();
    await restore;
  });

  testWidgets(
    'SessionScope: entrega la sesión y maybeOf devuelve null sin scope',
    (WidgetTester tester) async {
      final vm = _crear();
      SessionViewModel? conScope;
      SessionViewModel? sinScope = vm;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  sinScope = SessionScope.maybeOf(context);
                  return const SizedBox();
                },
              ),
              SessionScope(
                session: vm,
                child: Builder(
                  builder: (context) {
                    conScope = SessionScope.of(context);
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      );

      expect(identical(conScope, vm), isTrue);
      expect(sinScope, isNull);
    },
  );
}
