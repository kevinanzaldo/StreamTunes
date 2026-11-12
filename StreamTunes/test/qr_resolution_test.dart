import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/repositories/app_repositories.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/services/pending_follow_service.dart';
import 'package:streamtunes/services/qr_resolution_service.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/reproductor_view_model.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/views/band_public_view.dart';
import 'package:streamtunes/views/main_navigation_shell.dart';
import 'package:streamtunes/widgets/library_scope.dart';
import 'package:streamtunes/widgets/repositories_scope.dart';
import 'package:streamtunes/widgets/reproductor_scope.dart';
import 'package:streamtunes/widgets/session_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBandRepository bandRepo;
  late FakeAuthRepository authRepo;
  late PendingFollowService pendingFollowService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bandRepo = FakeBandRepository();
    authRepo = FakeAuthRepository();
    pendingFollowService = PendingFollowService();
  });

  group('QrResolutionService - Pruebas Unitarias (Criterio A1/F1)', () {
    test('Retorna null si no hay parámetro "band" en la URL', () async {
      final service = QrResolutionService(
        bandRepository: bandRepo,
        authRepository: authRepo,
        pendingFollowService: pendingFollowService,
        customUri: Uri.parse('https://streamtunes-web.vercel.app/'),
      );

      final result = await service.resolveStartupBand();
      expect(result, isNull);
    });

    test(
      'Resuelve banda válida y aprobada, firma anónimo y sigue a la banda',
      () async {
        final service = QrResolutionService(
          bandRepository: bandRepo,
          authRepository: authRepo,
          pendingFollowService: pendingFollowService,
          customUri: Uri.parse(
            'https://streamtunes-web.vercel.app/?band=los-subterraneos',
          ),
        );

        final result = await service.resolveStartupBand();

        expect(result, isNotNull);
        expect(result!.isSuccess, isTrue);
        expect(result.band?.slug, 'los-subterraneos');
        expect(result.offlineQueued, isFalse);
        expect(result.followMessage, contains('¡Ya estás siguiendo'));

        // Verificar que el usuario anónimo quedó autenticado y siguiendo a la banda
        final currentUser = await authRepo.restoreSession();
        expect(currentUser, isNotNull);
        final isFollowing = await bandRepo.isFollowingBand(result.band!.id);
        expect(isFollowing, isTrue);
      },
    );

    test('Muestra mensaje de error si la banda no existe', () async {
      final service = QrResolutionService(
        bandRepository: bandRepo,
        authRepository: authRepo,
        pendingFollowService: pendingFollowService,
        customUri: Uri.parse(
          'https://streamtunes-web.vercel.app/?band=banda-fantasma-inexistente',
        ),
      );

      final result = await service.resolveStartupBand();

      expect(result, isNotNull);
      expect(result!.isSuccess, isFalse);
      expect(result.band, isNull);
      expect(
        result.errorMessage,
        'La banda que buscás no existe o todavía no fue aprobada.',
      );
    });

    test(
      'Muestra mensaje de error si la banda no está aprobada (status pending)',
      () async {
        // Registrar una banda con status pending
        final pendingBand = Band(
          id: 'band_pending_test',
          name: 'Banda En Revisión',
          slug: 'banda-en-revision',
          genre: 'Indie',
          bio: 'Esperando moderación',
          status: BandStatus.pending,
          createdBy: 'user_pending',
          createdAt: DateTime(2026, 1, 1),
        );
        final pendingBandRepo = FakeBandRepository(initialBands: [pendingBand]);

        final service = QrResolutionService(
          bandRepository: pendingBandRepo,
          authRepository: authRepo,
          pendingFollowService: pendingFollowService,
          customUri: Uri.parse(
            'https://streamtunes-web.vercel.app/?band=banda-en-revision',
          ),
        );

        final result = await service.resolveStartupBand();

        expect(result, isNotNull);
        expect(result!.isSuccess, isFalse);
        expect(
          result.errorMessage,
          'La banda que buscás no existe o todavía no fue aprobada.',
        );
      },
    );

    test('Encola en PendingFollowService cuando falla la conexión (sótano offline)', () async {
      // Repo que arroja excepción de red al intentar seguir
      final offlineBandRepo = _OfflineFailingBandRepository();
      final service = QrResolutionService(
        bandRepository: offlineBandRepo,
        authRepository: authRepo,
        pendingFollowService: pendingFollowService,
        customUri: Uri.parse(
          'https://streamtunes-web.vercel.app/?band=los-subterraneos',
        ),
      );

      final result = await service.resolveStartupBand();

      expect(result, isNotNull);
      expect(result!.isSuccess, isTrue);
      expect(result.offlineQueued, isTrue);
      expect(
        result.followMessage,
        'Te vamos a anotar como seguidor cuando vuelva la conexión',
      );

      // Comprobar que el ID de la banda quedó encolado localmente
      final hasPending = await pendingFollowService.hasPendingFollow(
        'artist_1',
      );
      expect(hasPending, isTrue);
    });
  });

  group('MainNavigationShell - Integración QR y Modo Demo', () {
    testWidgets(
      'Muestra banner "Modo demo: datos de ejemplo" al usar Fake repos',
      (tester) async {
        final repos = AppRepositories(
          auth: authRepo,
          songs: FakeSongRepository(),
          bands: bandRepo,
          playlists: FakePlaylistRepository(),
          donations: FakeDonationRepository(),
        );
        final sessionVm = SessionViewModel(
          authRepository: authRepo,
          bandRepository: bandRepo,
        );
        final player = ReproductorViewModel();
        final library = LibraryViewModel(
          playlistRepository: repos.playlists,
          donationRepository: repos.donations,
        );
        addTearDown(player.dispose);
        addTearDown(library.dispose);

        final dummyQrService = QrResolutionService(
          bandRepository: bandRepo,
          authRepository: authRepo,
          pendingFollowService: pendingFollowService,
          customUri: Uri.parse('https://streamtunes-web.vercel.app/'),
        );

        await tester.pumpWidget(
          RepositoriesScope(
            repositories: repos,
            child: SessionScope(
              session: sessionVm,
              child: ReproductorScope(
                reproductor: player,
                child: LibraryScope(
                  library: library,
                  child: MaterialApp(
                    home: MainNavigationShell(
                      qrResolutionService: dummyQrService,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const ValueKey('demo_mode_banner')), findsOneWidget);
        expect(find.text('Modo demo: datos de ejemplo'), findsOneWidget);
      },
    );

    testWidgets(
      'Navega automáticamente a BandPublicView al resolver QR válido',
      (tester) async {
        final repos = AppRepositories(
          auth: authRepo,
          songs: FakeSongRepository(),
          bands: bandRepo,
          playlists: FakePlaylistRepository(),
          donations: FakeDonationRepository(),
        );
        final sessionVm = SessionViewModel(
          authRepository: authRepo,
          bandRepository: bandRepo,
        );
        final player = ReproductorViewModel();
        final library = LibraryViewModel(
          playlistRepository: repos.playlists,
          donationRepository: repos.donations,
        );
        addTearDown(player.dispose);
        addTearDown(library.dispose);

        final qrService = QrResolutionService(
          bandRepository: bandRepo,
          authRepository: authRepo,
          pendingFollowService: pendingFollowService,
          customUri: Uri.parse(
            'https://streamtunes-web.vercel.app/?band=los-subterraneos',
          ),
        );

        await tester.pumpWidget(
          RepositoriesScope(
            repositories: repos,
            child: SessionScope(
              session: sessionVm,
              child: ReproductorScope(
                reproductor: player,
                child: LibraryScope(
                  library: library,
                  child: MaterialApp(
                    home: MainNavigationShell(
                      qrResolutionService: qrService,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Debe abrir BandPublicView de Los Subterráneos
        expect(find.byType(BandPublicView), findsOneWidget);
        expect(find.text('Los Subterráneos'), findsWidgets);
      },
    );
  });
}

class _OfflineFailingBandRepository extends FakeBandRepository {
  @override
  Future<void> followBand(String bandId) async {
    throw Exception('Sin conexión a internet (sótano de recital)');
  }
}
