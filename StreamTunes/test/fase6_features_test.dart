import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/donation.dart';
import 'package:streamtunes/models/metricas_artista.dart';
import 'package:streamtunes/models/report.dart';
import 'package:streamtunes/repositories/app_repositories.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/fake/fake_report_repository.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/repositories/fake/fake_storage_repository.dart';
import 'package:streamtunes/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/view_models/band_public_view_model.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/views/admin_moderation_view.dart';
import 'package:streamtunes/widgets/repositories_scope.dart';
import 'package:streamtunes/widgets/session_scope.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase 6: Donaciones en vivo y tope de gastos', () {
    test(
      'FakeDonationRepository emite donaciones en tiempo real por stream',
      () async {
        final repo = FakeDonationRepository();
        final stream = repo.watchBandDonations('band_1');

        final emissionFuture = stream.first;

        await repo.addDonation(
          Donation(
            id: 'don_test_1',
            artistId: 'band_1',
            artistName: 'Los Subterráneos',
            amount: 1500,
            paymentMethod: 'Test',
            message: '¡Excelente música!',
          ),
        );

        final received = await emissionFuture;
        expect(received.id, 'don_test_1');
        expect(received.amount, 1500);
        expect(received.message, '¡Excelente música!');
        repo.dispose();
      },
    );

    test('BandPublicViewModel reacciona a donaciones en tiempo real y detecta spendCapActive', () async {
      final donationRepo = FakeDonationRepository();
      donationRepo.setSpendCapActive(true);
      final songRepo = FakeSongRepository();
      final band = Band(
        id: 'band_live',
        slug: 'band-live',
        name: 'Banda En Vivo',
        createdBy: 'user_1',
        createdAt: DateTime.now(),
      );

      final vm = BandPublicViewModel(
        band: band,
        songRepository: songRepo,
        donationRepository: donationRepo,
      );

      await vm.load();
      expect(vm.spendCapActive, isTrue);
      expect(vm.latestDonationAlert, isNull);

      // Emitir donación
      await donationRepo.addDonation(
        Donation(
          id: 'don_stream',
          artistId: 'band_live',
          artistName: 'Banda En Vivo',
          amount: 2500,
          paymentMethod: 'MP',
          message: 'Aguante la banda',
        ),
      );

      // El VM debió capturarla en tiempo real
      expect(vm.latestDonationAlert, isNotNull);
      expect(vm.latestDonationAlert!.amount, 2500);
      expect(vm.recentDonations.length, 1);

      vm.dismissAlert();
      expect(vm.latestDonationAlert, isNull);
      vm.dispose();
      donationRepo.dispose();
    });
  });

  group('Fase 6: Estadísticas y Top Fans', () {
    test('BandDashboardViewModel carga ranking de fans opt-in y reacciona a donaciones', () async {
      final songRepo = FakeSongRepository();
      final donationRepo = FakeDonationRepository();
      final bandRepo = FakeBandRepository(
        initialTopFans: {
          'band_dash': const [
            OyenteTop(nombre: 'Caro Gómez', minutos: 142, isPublic: true),
            OyenteTop(nombre: 'Oculto', minutos: 95, isPublic: false),
          ],
        },
      );
      final band = Band(
        id: 'band_dash',
        slug: 'band-dash',
        name: 'Banda Dashboard',
        createdBy: 'user_1',
        createdAt: DateTime.now(),
      );

      final vm = BandDashboardViewModel(
        band: band,
        songRepository: songRepo,
        donationRepository: donationRepo,
        bandRepository: bandRepo,
      );

      await vm.load();
      expect(vm.topFans.length, 2);
      expect(vm.topFans.first.nombre, 'Caro Gómez');
      expect(vm.topFans.first.minutos, 142);
      expect(vm.topFans.last.nombre, 'Fan anónimo');

      // Nueva donación
      await donationRepo.addDonation(
        Donation(
          id: 'don_dash',
          artistId: 'band_dash',
          artistName: 'Banda Dashboard',
          amount: 500,
          paymentMethod: 'MP',
        ),
      );

      expect(vm.donations.length, 1);
      expect(vm.donations.first.id, 'don_dash');
      vm.dispose();
      donationRepo.dispose();
    });
  });

  group('Fase 6: Reportes y Moderación', () {
    test('FakeReportRepository crea, lista y resuelve reportes', () async {
      final repo = FakeReportRepository();

      final reportesIniciales = await repo.getReports(
        status: ReportStatus.open,
      );
      expect(reportesIniciales.length, 2);

      final nuevo = await repo.createReport(
        reason: 'Contenido ofensivo en el tema',
        songId: 'song_99',
      );
      expect(nuevo.status, ReportStatus.open);

      final despuesDeCrear = await repo.getReports(status: ReportStatus.open);
      expect(despuesDeCrear.length, 3);

      await repo.resolveReport(nuevo.id, dismiss: false);
      final resueltos = await repo.getReports(status: ReportStatus.resolved);
      expect(resueltos.any((r) => r.id == nuevo.id), isTrue);

      final abiertos = await repo.getReports(status: ReportStatus.open);
      expect(abiertos.any((r) => r.id == nuevo.id), isFalse);
    });

    testWidgets('AdminModerationView: permite aprobar bandas pendientes', (
      tester,
    ) async {
      final authRepo = FakeAuthRepository();
      final songRepo = FakeSongRepository();
      final bandRepo = FakeBandRepository();
      final playlistRepo = FakePlaylistRepository();
      final donationRepo = FakeDonationRepository();
      final storageRepo = FakeStorageRepository();
      final reportRepo = FakeReportRepository();

      // Crear una banda que nazca pending
      await bandRepo.createBand(
        Band(
          id: 'band_pending_1',
          slug: 'band-nueva-test',
          name: 'Banda Nueva Test',
          bio: 'Bio de prueba',
          createdBy: 'user_caro',
          createdAt: DateTime.now(),
        ),
      );

      final repos = AppRepositories(
        auth: authRepo,
        songs: songRepo,
        bands: bandRepo,
        playlists: playlistRepo,
        donations: donationRepo,
        storage: storageRepo,
        reports: reportRepo,
      );

      final sessionVM = SessionViewModel(
        authRepository: authRepo,
        bandRepository: bandRepo,
      );
      // Login como admin
      await sessionVM.signIn(
        email: 'admin@streamtunes.test',
        password: FakeAuthRepository.demoPassword,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RepositoriesScope(
            repositories: repos,
            child: SessionScope(
              session: sessionVM,
              child: const AdminModerationView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Comprobar que aparece la banda pendiente
      expect(find.text('Banda Nueva Test'), findsOneWidget);
      expect(find.text('Aprobar banda'), findsOneWidget);

      // Tocar aprobar
      await tester.tap(find.text('Aprobar banda'));
      await tester.pumpAndSettle();

      // Comprobar que ahora no hay bandas pendientes
      expect(
        find.text('No hay bandas pendientes de aprobación.'),
        findsOneWidget,
      );

      final aprobadas = await bandRepo.getApprovedBands();
      expect(aprobadas.any((b) => b.name == 'Banda Nueva Test'), isTrue);
    });
  });
}
