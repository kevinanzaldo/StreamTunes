import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/repositories/app_repositories.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/fake/fake_report_repository.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/view_models/home_view_model.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/views/admin_moderation_view.dart';
import 'package:streamtunes/views/band_dashboard_view.dart';
import 'package:streamtunes/views/band_public_view.dart';
import 'package:streamtunes/views/home_view.dart';
import 'package:streamtunes/views/library_view.dart';
import 'package:streamtunes/widgets/empty_state_view.dart';
import 'package:streamtunes/widgets/library_scope.dart';
import 'package:streamtunes/widgets/repositories_scope.dart';
import 'package:streamtunes/widgets/session_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBandRepository bandRepo;
  late FakeSongRepository songRepo;
  late FakePlaylistRepository playlistRepo;
  late FakeDonationRepository donationRepo;
  late FakeAuthRepository authRepo;
  late FakeReportRepository reportRepo;
  late AppRepositories repos;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bandRepo = FakeBandRepository();
    songRepo = FakeSongRepository();
    playlistRepo = FakePlaylistRepository();
    donationRepo = FakeDonationRepository();
    authRepo = FakeAuthRepository();
    reportRepo = FakeReportRepository();
    repos = AppRepositories(
      auth: authRepo,
      songs: songRepo,
      bands: bandRepo,
      playlists: playlistRepo,
      donations: donationRepo,
      reports: reportRepo,
    );
  });

  group('EmptyStateView - Componente Reutilizable (Criterio B1)', () {
    testWidgets('Renderiza icono, título, descripción y botones de acción', (
      tester,
    ) async {
      bool actionTapped = false;
      bool secondaryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              icon: Icons.music_note,
              title: 'Título de Prueba',
              description: 'Descripción detallada del estado',
              actionLabel: 'Acción Principal',
              onAction: () => actionTapped = true,
              secondaryActionLabel: 'Acción Secundaria',
              onSecondaryAction: () => secondaryTapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.music_note), findsOneWidget);
      expect(find.text('Título de Prueba'), findsOneWidget);
      expect(find.text('Descripción detallada del estado'), findsOneWidget);
      expect(find.text('Acción Principal'), findsOneWidget);
      expect(find.text('Acción Secundaria'), findsOneWidget);

      await tester.tap(find.text('Acción Principal'));
      expect(actionTapped, isTrue);

      await tester.tap(find.text('Acción Secundaria'));
      expect(secondaryTapped, isTrue);
    });

    testWidgets(
      'LibraryView muestra EmptyStateView con "Todavía no armaste ninguna playlist"',
      (tester) async {
        final emptyPlaylistRepo = FakePlaylistRepository(
          initialPlaylists: const [],
        );
        final libVm = LibraryViewModel(
          playlistRepository: emptyPlaylistRepo,
          donationRepository: donationRepo,
        );
        final sessionVm = SessionViewModel(
          authRepository: authRepo,
          bandRepository: bandRepo,
        );
        // Simular usuario autenticado para pasar el SessionGate
        await sessionVm.restore();
        await sessionVm.signIn(
          email: 'caro@streamtunes.test',
          password: FakeAuthRepository.demoPassword,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RepositoriesScope(
              repositories: AppRepositories(
                auth: authRepo,
                songs: songRepo,
                bands: bandRepo,
                playlists: emptyPlaylistRepo,
                donations: donationRepo,
              ),
              child: SessionScope(
                session: sessionVm,
                child: LibraryScope(library: libVm, child: const LibraryView()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmptyStateView), findsOneWidget);
        expect(
          find.text('Todavía no armaste ninguna playlist'),
          findsOneWidget,
        );
        expect(find.text('Crear mi primera playlist'), findsOneWidget);
      },
    );

    testWidgets('HomeView muestra EmptyStateView cuando no hay canciones', (
      tester,
    ) async {
      final emptySongRepo = FakeSongRepository(initialSongs: const []);
      final homeVm = HomeViewModel(
        songRepository: emptySongRepo,
        bandRepository: bandRepo,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RepositoriesScope(
            repositories: AppRepositories(
              auth: authRepo,
              songs: emptySongRepo,
              bands: bandRepo,
            ),
            child: HomeView(viewModel: homeVm),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('Todavía no hay lanzamientos'), findsOneWidget);
    });

    testWidgets(
      'BandPublicView muestra EmptyStateView para fechas y fotos vacías',
      (tester) async {
        final band = Band(
          id: 'band_empty_state_test',
          name: 'Banda Sin Agenda Ni Fotos',
          slug: 'banda-vacia',
          genre: 'Indie',
          bio: 'Banda nueva',
          createdBy: 'user_test',
          createdAt: DateTime(2026, 1, 1),
        );
        final sessionVm = SessionViewModel(
          authRepository: authRepo,
          bandRepository: bandRepo,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RepositoriesScope(
              repositories: repos,
              child: SessionScope(
                session: sessionVm,
                child: BandPublicView(band: band),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sin fechas confirmadas'), findsOneWidget);
        expect(find.text('Sin fotos todavía'), findsOneWidget);
      },
    );

    testWidgets(
      'BandDashboardView muestra EmptyStateView con "Subir mi primer tema" cuando no hay canciones',
      (tester) async {
        final band = Band(
          id: 'band_no_songs_test',
          name: 'Banda Sin Temas',
          slug: 'banda-sin-temas',
          genre: 'Rock',
          bio: 'Banda nueva',
          createdBy: 'user_test',
          createdAt: DateTime(2026, 1, 1),
        );
        final emptySongRepo = FakeSongRepository(initialSongs: const []);
        final sessionVm = SessionViewModel(
          authRepository: authRepo,
          bandRepository: bandRepo,
        );
        final dashVm = BandDashboardViewModel(
          band: band,
          songRepository: emptySongRepo,
          donationRepository: donationRepo,
          bandRepository: bandRepo,
        );
        await dashVm.load();

        await tester.pumpWidget(
          MaterialApp(
            home: RepositoriesScope(
              repositories: repos,
              child: SessionScope(
                session: sessionVm,
                child: BandDashboardView(band: band, viewModel: dashVm),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Todavía no subiste ninguna canción'), findsOneWidget);
        expect(find.text('Subir mi primer tema'), findsOneWidget);
        expect(find.text('Recargar'), findsOneWidget);
      },
    );

    testWidgets(
      'AdminModerationView muestra EmptyStateView cuando no hay bandas pendientes',
      (tester) async {
        final emptyBandRepo = FakeBandRepository(initialBands: const []);
        final emptyReportRepo = FakeReportRepository(const []);
        final sessionVm = SessionViewModel(
          authRepository: authRepo,
          bandRepository: emptyBandRepo,
        );
        addTearDown(sessionVm.dispose);
        await sessionVm.restore();
        await sessionVm.signIn(
          email: 'admin@streamtunes.test',
          password: FakeAuthRepository.demoPassword,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RepositoriesScope(
              repositories: AppRepositories(
                auth: authRepo,
                songs: songRepo,
                bands: emptyBandRepo,
                reports: emptyReportRepo,
              ),
              child: SessionScope(
                session: sessionVm,
                child: const AdminModerationView(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('No hay bandas pendientes de aprobación.'),
          findsOneWidget,
        );
      },
    );
  });
}
