import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/donation.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/app_repositories.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/view_models/band_public_view_model.dart';
import 'package:streamtunes/widgets/repositories_scope.dart';

Band _sampleBand() => Band(
  id: 'artist_1',
  slug: 'band-test-1',
  name: 'Banda Prueba',
  bio: 'Bio de prueba',
  genre: 'Indie Rock',
  location: 'Buenos Aires',
  status: BandStatus.approved,
  createdBy: 'user_1',
  createdAt: DateTime(2026, 1, 1),
);

class _FlakySongRepository extends FakeSongRepository {
  int calls = 0;

  @override
  Future<List<Song>> getSongsByBand(String bandId) async {
    calls++;
    if (calls == 1) throw Exception('sin red');
    return super.getSongsByBand(bandId);
  }
}

AppRepositories _repositoriosDePrueba() => AppRepositories(
  auth: FakeAuthRepository(),
  songs: FakeSongRepository(),
  bands: FakeBandRepository(),
  playlists: FakePlaylistRepository(),
  donations: FakeDonationRepository(),
);

void main() {
  group('BandPublicViewModel', () {
    test(
      'load() trae canciones de la banda ordenadas por reproducciones',
      () async {
        final songRepo = FakeSongRepository(
          initialSongs: [
            Song(
              id: 's1',
              title: 'Tema 1',
              artistId: 'artist_1',
              artistName: 'Banda Prueba',
              album: 'Album 1',
              duration: const Duration(minutes: 3),
              genre: 'Rock',
              icon: Icons.music_note,
              gradientColors: const [Colors.red, Colors.blue],
              playCount: 10,
              uploadedAt: DateTime(2026, 1, 1),
            ),
            Song(
              id: 's2',
              title: 'Tema 2',
              artistId: 'artist_1',
              artistName: 'Banda Prueba',
              album: 'Album 1',
              duration: const Duration(minutes: 3),
              genre: 'Rock',
              icon: Icons.music_note,
              gradientColors: const [Colors.red, Colors.blue],
              playCount: 50,
              uploadedAt: DateTime(2026, 1, 2),
            ),
          ],
        );

        final vm = BandPublicViewModel(
          band: _sampleBand(),
          songRepository: songRepo,
          donationRepository: FakeDonationRepository(),
        );
        addTearDown(vm.dispose);

        await vm.load();

        expect(vm.isLoading, isFalse);
        expect(vm.error, isNull);
        expect(vm.songs, hasLength(2));
        expect(vm.songs.first.id, 's2');
        expect(vm.songs.last.id, 's1');
      },
    );

    test('reintento ante error recupera la lista de temas', () async {
      final vm = BandPublicViewModel(
        band: _sampleBand(),
        songRepository: _FlakySongRepository(),
        donationRepository: FakeDonationRepository(),
      );
      addTearDown(vm.dispose);

      await vm.load();
      expect(vm.error, isNotNull);
      expect(vm.songs, isEmpty);

      await vm.load();
      expect(vm.error, isNull);
      expect(vm.songs, isNotEmpty);
    });
  });

  group('DonationRepository y Realtime con StreamController', () {
    test(
      'watchBandDonations emite eventos en vivo al agregar donaciones',
      () async {
        final donationRepo = FakeDonationRepository();
        addTearDown(donationRepo.dispose);

        final stream = donationRepo.watchBandDonations('artist_1');
        final received = <Donation>[];
        final sub = stream.listen(received.add);
        addTearDown(sub.cancel);

        await donationRepo.addDonation(
          Donation(
            id: 'don_1',
            artistId: 'artist_1',
            artistName: 'Banda Prueba',
            amount: 500,
            paymentMethod: 'MercadoPago',
            donorName: 'Fan Donante',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(received, hasLength(1));
        expect(received.first.amount, 500);
        expect(received.first.donorName, 'Fan Donante');
      },
    );

    test(
      'BandDashboardViewModel actualiza muro en vivo al emitir en el stream',
      () async {
        final donationRepo = FakeDonationRepository();
        addTearDown(donationRepo.dispose);

        final vm = BandDashboardViewModel(
          band: _sampleBand(),
          songRepository: FakeSongRepository(),
          donationRepository: donationRepo,
        );
        addTearDown(vm.dispose);

        await vm.load();
        final initialDonationCount = vm.donations.length;

        await donationRepo.addDonation(
          Donation(
            id: 'don_live',
            artistId: 'artist_1',
            artistName: 'Banda Prueba',
            amount: 1500,
            paymentMethod: 'Transferencia',
            donorName: 'Oyente Frecuente',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(vm.donations.length, initialDonationCount + 1);
        expect(vm.donations.first.amount, 1500);
      },
    );
  });

  group('RepositoriesScope', () {
    testWidgets('entrega los repositorios inyectados', (tester) async {
      final repos = _repositoriosDePrueba();
      AppRepositories? leidos;

      await tester.pumpWidget(
        RepositoriesScope(
          repositories: repos,
          child: Builder(
            builder: (context) {
              leidos = RepositoriesScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(identical(leidos, repos), isTrue);
    });

    testWidgets('sin scope usa un respaldo en memoria compartido', (
      tester,
    ) async {
      late AppRepositories primero;
      late AppRepositories segundo;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            primero = RepositoriesScope.of(context);
            segundo = RepositoriesScope.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(identical(primero, segundo), isTrue);
      expect(await primero.songs.getLatestSongs(), isNotEmpty);
    });
  });
}
