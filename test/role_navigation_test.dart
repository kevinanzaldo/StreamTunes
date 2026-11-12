import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/reproductor_view_model.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/views/main_navigation_shell.dart';
import 'package:streamtunes/widgets/library_scope.dart';
import 'package:streamtunes/widgets/reproductor_scope.dart';
import 'package:streamtunes/widgets/session_scope.dart';

void main() {
  late FakeAuthRepository authRepo;
  late FakeBandRepository bandRepo;
  late SessionViewModel session;
  late ReproductorViewModel player;
  late LibraryViewModel library;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authRepo = FakeAuthRepository();
    bandRepo = FakeBandRepository();
    session = SessionViewModel(
      authRepository: authRepo,
      bandRepository: bandRepo,
    );
    player = ReproductorViewModel();
    library = LibraryViewModel(
      playlistRepository: FakePlaylistRepository(),
      donationRepository: FakeDonationRepository(),
    );
  });

  tearDown(() {
    session.dispose();
    player.dispose();
    library.dispose();
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: SessionScope(
        session: session,
        child: ReproductorScope(
          reproductor: player,
          child: LibraryScope(
            library: library,
            child: const MainNavigationShell(),
          ),
        ),
      ),
    );
  }

  testWidgets('Visitante: solo ve 2 pestañas (Inicio y Cuenta)', (
    WidgetTester tester,
  ) async {
    await session.restore();

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Cuenta'), findsOneWidget);
    expect(find.text('Subir'), findsNothing);
    expect(find.text('Playlists'), findsNothing);
    expect(find.text('Mi banda'), findsNothing);
  });

  testWidgets('Oyente sin banda: ve 3 pestañas y no ve Subir ni Mi banda', (
    WidgetTester tester,
  ) async {
    await session.restore();
    await session.signIn(
      email: 'caro@streamtunes.test',
      password: FakeAuthRepository.demoPassword,
    );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(session.isLoggedIn, isTrue);
    expect(session.hasBand, isFalse);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Cuenta'), findsOneWidget);
    expect(find.text('Subir'), findsNothing);
    expect(find.text('Mi banda'), findsNothing);
  });

  testWidgets(
    'Miembro de banda: ve la pestaña Mi banda y puede abrir el panel',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await session.restore();
      await session.signIn(
        email: 'ana@streamtunes.test',
        password: FakeAuthRepository.demoPassword,
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(session.isLoggedIn, isTrue);
      expect(session.hasBand, isTrue);
      expect(find.text('Mi banda'), findsOneWidget);

      // Tocar en 'Mi banda'
      await tester.tap(find.text('Mi banda'));
      await tester.pumpAndSettle();

      expect(find.text('Panel: Los Subterráneos'), findsOneWidget);
    },
  );

  testWidgets(
    'Pantalla ancha (>=600px): NavigationRail incluye Mi banda para miembro de banda',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await session.restore();
      await session.signIn(
        email: 'ana@streamtunes.test',
        password: FakeAuthRepository.demoPassword,
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Mi banda'), findsOneWidget);
    },
  );

  testWidgets(
    'Cierre de sesión dinámico: remueve Mi banda sin romper navegación',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await session.restore();
      await session.signIn(
        email: 'ana@streamtunes.test',
        password: FakeAuthRepository.demoPassword,
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Mi banda'), findsOneWidget);

      // Cerrar sesión
      await session.signOut();
      await tester.pumpAndSettle();

      expect(find.text('Mi banda'), findsNothing);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Cuenta'), findsOneWidget);
    },
  );
}
