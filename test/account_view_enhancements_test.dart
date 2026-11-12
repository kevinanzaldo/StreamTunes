import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/models/donation.dart';
import 'package:streamtunes/repositories/app_repositories.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/reproductor_view_model.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/views/account_view.dart';
import 'package:streamtunes/views/band_dashboard_view.dart';
import 'package:streamtunes/widgets/library_scope.dart';
import 'package:streamtunes/widgets/repositories_scope.dart';
import 'package:streamtunes/widgets/reproductor_scope.dart';
import 'package:streamtunes/widgets/session_scope.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('AccountView: muestra botón de abrir panel de la banda activa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = FakeAuthRepository();
    final bands = FakeBandRepository();
    final session = SessionViewModel(
      authRepository: auth,
      bandRepository: bands,
    );
    addTearDown(session.dispose);

    await session.restore();
    await session.signIn(
      email: 'ana@streamtunes.test',
      password: FakeAuthRepository.demoPassword,
    );

    final repos = AppRepositories(
      songs: FakeSongRepository(),
      bands: bands,
      playlists: FakePlaylistRepository(),
      donations: FakeDonationRepository(),
      auth: auth,
    );

    final player = ReproductorViewModel();
    final library = LibraryViewModel(
      playlistRepository: repos.playlists,
      donationRepository: repos.donations,
    );
    addTearDown(player.dispose);
    addTearDown(library.dispose);

    await tester.pumpWidget(
      RepositoriesScope(
        repositories: repos,
        child: SessionScope(
          session: session,
          child: ReproductorScope(
            reproductor: player,
            child: LibraryScope(
              library: library,
              child: const MaterialApp(home: AccountView()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('open_band_dashboard')), findsOneWidget);
    expect(find.text('Mis aportes al Colectivo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open_band_dashboard')));
    await tester.pumpAndSettle();

    expect(find.byType(BandDashboardView), findsOneWidget);
  });

  testWidgets('AccountView: muestra donaciones realizadas en Mis aportes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = FakeAuthRepository();
    final bands = FakeBandRepository();
    final donationRepo = FakeDonationRepository();
    await donationRepo.addDonation(
      Donation(
        id: 'don_1',
        artistId: 'art_1',
        artistName: 'Los Subterráneos',
        amount: 2500,
        message: '¡Excelente disco!',
        paymentMethod: 'MercadoPago',
      ),
    );

    final session = SessionViewModel(
      authRepository: auth,
      bandRepository: bands,
    );
    addTearDown(session.dispose);

    await session.restore();
    await session.signIn(
      email: 'ana@streamtunes.test',
      password: FakeAuthRepository.demoPassword,
    );

    final repos = AppRepositories(
      songs: FakeSongRepository(),
      bands: bands,
      playlists: FakePlaylistRepository(),
      donations: donationRepo,
      auth: auth,
    );

    final player = ReproductorViewModel();
    final library = LibraryViewModel(
      playlistRepository: repos.playlists,
      donationRepository: repos.donations,
    );
    addTearDown(player.dispose);
    addTearDown(library.dispose);

    await tester.pumpWidget(
      RepositoriesScope(
        repositories: repos,
        child: SessionScope(
          session: session,
          child: ReproductorScope(
            reproductor: player,
            child: LibraryScope(
              library: library,
              child: const MaterialApp(home: AccountView()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¡Excelente disco!'), findsOneWidget);
    expect(find.text('\$ARS 2500'), findsOneWidget);
  });
}
