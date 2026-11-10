import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/mock_data.dart';
import 'package:streamtunes/main.dart';
import 'package:streamtunes/models/artist.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/view_models/artist_detail_view_model.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/reproductor_view_model.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/views/account_view.dart';
import 'package:streamtunes/views/artist_detail_view.dart';
import 'package:streamtunes/widgets/library_scope.dart';
import 'package:streamtunes/widgets/reproductor_scope.dart';
import 'package:streamtunes/widgets/session_scope.dart';

const _pass = FakeAuthRepository.demoPassword;

SessionViewModel _crearSesion() {
  final vm = SessionViewModel(
    authRepository: FakeAuthRepository(),
    bandRepository: FakeBandRepository(),
  );
  addTearDown(vm.dispose);
  return vm;
}

void _pantallaGrande(WidgetTester tester, {double alto = 1600}) {
  tester.view.physicalSize = Size(800, alto);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Muestra "Mi cuenta" con una sesión ya restaurada. Si se pasa [email], la
/// persona inicia sesión antes de mostrar la pantalla.
Future<SessionViewModel> _mostrarCuenta(
  WidgetTester tester, {
  String? email,
}) async {
  _pantallaGrande(tester);
  final session = _crearSesion();
  await session.restore();
  if (email != null) await session.signIn(email: email, password: _pass);

  await tester.pumpWidget(
    SessionScope(
      session: session,
      child: const MaterialApp(home: AccountView()),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets('Cuenta: un visitante ve el formulario de ingreso', (
    WidgetTester tester,
  ) async {
    await _mostrarCuenta(tester);

    expect(find.byKey(const ValueKey('login_email')), findsOneWidget);
    expect(find.byKey(const ValueKey('login_password')), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsNothing);
  });

  testWidgets(
    'Cuenta: ingresar con datos correctos muestra la persona y sus bandas',
    (WidgetTester tester) async {
      await _mostrarCuenta(tester);

      await tester.enterText(
        find.byKey(const ValueKey('login_email')),
        'ana@streamtunes.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login_password')),
        _pass,
      );
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Ana Quiroga'), findsOneWidget);
      expect(find.text(MockData.artists.first.name), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);
    },
  );

  testWidgets(
    'Cuenta: una contraseña incorrecta muestra el error en pantalla',
    (WidgetTester tester) async {
      await _mostrarCuenta(tester);

      await tester.enterText(
        find.byKey(const ValueKey('login_email')),
        'ana@streamtunes.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login_password')),
        'incorrecta',
      );
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Email o contraseña incorrectos.'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
    },
  );

  testWidgets(
    'Cuenta: registrarse crea la cuenta, cierra el formulario y muestra el perfil',
    (WidgetTester tester) async {
      await _mostrarCuenta(tester);

      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('register_name')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('register_name')),
        'Nico Paz',
      );
      await tester.enterText(
        find.byKey(const ValueKey('register_email')),
        'nico@mail.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('register_password')),
        'Clave1234',
      );
      await tester.tap(find.text('Registrarme'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('register_name')), findsNothing);
      expect(find.text('Nico Paz'), findsOneWidget);
      expect(
        find.text('Todavía no tenés bandas. Creá la tuya para subir música.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Cuenta: crear una banda la muestra como pendiente de aprobación',
    (WidgetTester tester) async {
      await _mostrarCuenta(tester, email: 'caro@streamtunes.test');

      await tester.tap(find.text('Crear mi banda'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('create_band_name')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('create_band_name')),
        'Los Nuevos',
      );
      await tester.tap(find.text('Crear banda'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('create_band_name')), findsNothing);
      expect(find.text('Los Nuevos'), findsOneWidget);
      expect(find.textContaining('Pendiente de aprobación'), findsOneWidget);
    },
  );

  testWidgets('Cuenta: cerrar sesión vuelve al formulario de ingreso', (
    WidgetTester tester,
  ) async {
    await _mostrarCuenta(tester, email: 'caro@streamtunes.test');
    expect(find.text('Caro Funes'), findsOneWidget);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Caro Funes'), findsNothing);
  });

  testWidgets(
    'StreamTunesApp: la pestaña Cuenta muestra el formulario de ingreso',
    (WidgetTester tester) async {
      await tester.pumpWidget(const StreamTunesApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Entrar'), findsOneWidget);
    },
  );

  testWidgets(
    'Estadísticas privadas con sesión: solo las ve quien es miembro de la banda',
    (WidgetTester tester) async {
      _pantallaGrande(tester, alto: 4000);

      final player = ReproductorViewModel();
      final library = LibraryViewModel();
      addTearDown(player.dispose);
      addTearDown(library.dispose);

      Future<void> mostrarPerfil({
        required String? email,
        required Artist artist,
      }) async {
        final session = _crearSesion();
        await session.restore();
        if (email != null) await session.signIn(email: email, password: _pass);

        final vm = ArtistDetailViewModel(
          artist: artist,
          autoEscucharDonaciones: false,
        );
        addTearDown(vm.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SessionScope(
              session: session,
              child: ReproductorScope(
                reproductor: player,
                child: LibraryScope(
                  library: library,
                  child: ArtistDetailView(
                    key: ValueKey('${email}_${artist.id}'),
                    artist: artist,
                    viewModel: vm,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      const panelEstadisticas = 'Métricas en Segundo Plano (Isolate)';
      final suya = MockData.artists[0];
      final ajena = MockData.artists[1];

      // Ana es miembro de su banda: ve las estadísticas.
      await mostrarPerfil(email: 'ana@streamtunes.test', artist: suya);
      expect(find.text(panelEstadisticas), findsOneWidget);

      // Ana mirando otra banda: no las ve.
      await mostrarPerfil(email: 'ana@streamtunes.test', artist: ajena);
      expect(find.text(panelEstadisticas), findsNothing);

      // Un visitante (con sesión disponible pero sin iniciar) no las ve.
      await mostrarPerfil(email: null, artist: suya);
      expect(find.text(panelEstadisticas), findsNothing);
    },
  );
}
