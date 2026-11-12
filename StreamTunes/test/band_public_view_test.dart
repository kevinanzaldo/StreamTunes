import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/config/app_constants.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/app_repositories.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/repositories/interfaces/song_repository.dart';
import 'package:streamtunes/view_models/band_public_view_model.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/reproductor_view_model.dart';
import 'package:streamtunes/views/band_public_view.dart';
import 'package:streamtunes/widgets/library_scope.dart';
import 'package:streamtunes/widgets/now_playing_modal.dart';
import 'package:streamtunes/widgets/repositories_scope.dart';
import 'package:streamtunes/widgets/reproductor_scope.dart';

Band _testBand({String id = 'band_test', String name = 'Los Pruebas'}) {
  return Band(
    id: id,
    slug: 'los-pruebas',
    name: name,
    bio: 'Banda independiente de prueba.',
    genre: 'Rock Indie',
    location: 'Buenos Aires',
    donationGoal: 10000,
    donationsCollected: 2500,
    status: BandStatus.approved,
    createdBy: 'user_1',
    createdAt: DateTime(2026, 1, 1),
  );
}

class _FlakySongRepo implements SongRepository {
  bool shouldFail = true;

  @override
  Future<List<Song>> getLatestSongs({int limit = 50}) async => [];

  @override
  Future<List<Song>> getSongsByBand(String bandId) async {
    if (shouldFail) throw Exception('sin red');
    return [
      Song(
        id: 's1',
        title: 'Tema Menos Escuchado',
        artistId: bandId,
        artistName: 'Los Pruebas',
        album: 'Demo',
        duration: const Duration(minutes: 3),
        genre: 'Rock',
        icon: Icons.music_note,
        gradientColors: const [Colors.purple, Colors.blue],
        playCount: 10,
        uploadedAt: DateTime.now(),
      ),
      Song(
        id: 's2',
        title: 'Hit Más Escuchado',
        artistId: bandId,
        artistName: 'Los Pruebas',
        album: 'Demo',
        duration: const Duration(minutes: 4),
        genre: 'Rock',
        icon: Icons.music_note,
        gradientColors: const [Colors.purple, Colors.blue],
        playCount: 500,
        uploadedAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<Song> addSong(Song song, {String? albumId}) async => song;

  @override
  Future<void> recordPlayEvent({
    required String songId,
    required String bandId,
    required int secondsListened,
    String? userId,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getPlayEventsByBand(String bandId) async =>
      const [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'BandPublicViewModel: carga y ordena temas por reproducciones descendente',
    () async {
      final repo = _FlakySongRepo()..shouldFail = false;
      final vm = BandPublicViewModel(
        band: _testBand(),
        songRepository: repo,
        donationRepository: FakeDonationRepository(),
      );

      await vm.load();

      expect(vm.isLoading, isFalse);
      expect(vm.error, isNull);
      expect(vm.songs.length, 2);
      expect(vm.songs.first.title, 'Hit Más Escuchado');
      expect(vm.songs.last.title, 'Tema Menos Escuchado');
    },
  );

  test(
    'BandPublicViewModel: maneja error de carga y reintento exitoso',
    () async {
      final repo = _FlakySongRepo()..shouldFail = true;
      final vm = BandPublicViewModel(
        band: _testBand(),
        songRepository: repo,
        donationRepository: FakeDonationRepository(),
      );

      await vm.load();
      expect(vm.isLoading, isFalse);
      expect(vm.error, isNotNull);
      expect(vm.songs, isEmpty);

      repo.shouldFail = false;
      await vm.load();
      expect(vm.error, isNull);
      expect(vm.songs.length, 2);
    },
  );

  test('BandPublicViewModel: registra donación correctamente', () async {
    final donations = FakeDonationRepository();
    final vm = BandPublicViewModel(
      band: _testBand(),
      songRepository: FakeSongRepository(),
      donationRepository: donations,
    );

    final ok = await vm.donate(amount: 1500, message: '¡Fuerza!');
    expect(ok, isTrue);
  });

  test('BandPublicViewModel: respeta maxDonationArs y valida montos desde constante compartida', () async {
    final donations = FakeDonationRepository()..setMaxDonationArs(2000);
    final vm = BandPublicViewModel(
      band: _testBand(),
      songRepository: FakeSongRepository(),
      donationRepository: donations,
    );

    await vm.load();
    expect(vm.maxDonationArs, 2000);
    expect(vm.donationAmounts, [500.0, 1000.0, 2000.0]);
    expect(kDonationAmountsArs, [500.0, 1000.0, 2000.0, 5000.0]);
    expect(await vm.donate(amount: 5000, message: 'Excede tope'), isFalse);
    expect(await vm.donate(amount: 2000, message: 'Dentro de tope'), isTrue);
  });

  testWidgets('BandPublicView: muestra datos de la banda y temas', (
    tester,
  ) async {
    final repo = _FlakySongRepo()..shouldFail = false;
    final vm = BandPublicViewModel(
      band: _testBand(),
      songRepository: repo,
      donationRepository: FakeDonationRepository(),
    );
    await vm.load();

    final player = ReproductorViewModel();
    final library = LibraryViewModel(
      playlistRepository: FakePlaylistRepository(),
      donationRepository: FakeDonationRepository(),
    );
    addTearDown(player.dispose);
    addTearDown(library.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ReproductorScope(
          reproductor: player,
          child: LibraryScope(
            library: library,
            child: BandPublicView(band: _testBand(), viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Los Pruebas'), findsWidgets);
    expect(find.text('Rock Indie'), findsOneWidget);
    expect(find.text('Buenos Aires'), findsOneWidget);
    expect(find.text('Hit Más Escuchado'), findsOneWidget);
    expect(find.text('Tema Menos Escuchado'), findsOneWidget);
    expect(find.text('Apoyar'), findsOneWidget);
    expect(find.text('Reportar'), findsOneWidget);
  });

  testWidgets(
    'BandPublicView: soporte responsivo en pantalla ancha (>=600 px)',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FlakySongRepo()..shouldFail = false;
      final vm = BandPublicViewModel(
        band: _testBand(),
        songRepository: repo,
        donationRepository: FakeDonationRepository(),
      );
      await vm.load();

      final player = ReproductorViewModel();
      final library = LibraryViewModel(
        playlistRepository: FakePlaylistRepository(),
        donationRepository: FakeDonationRepository(),
      );
      addTearDown(player.dispose);
      addTearDown(library.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ReproductorScope(
            reproductor: player,
            child: LibraryScope(
              library: library,
              child: BandPublicView(band: _testBand(), viewModel: vm),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.text('Temas más escuchados'), findsOneWidget);
    },
  );

  testWidgets(
    'NowPlayingModal: tocar el nombre de la banda abre BandPublicView real',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final song = (await FakeSongRepository().getLatestSongs()).first;
      final repos = AppRepositories(
        auth: FakeAuthRepository(),
        songs: FakeSongRepository(),
        bands: FakeBandRepository(),
        playlists: FakePlaylistRepository(),
        donations: FakeDonationRepository(),
      );
      final player = ReproductorViewModel()..play(song);
      final library = LibraryViewModel(
        playlistRepository: FakePlaylistRepository(),
        donationRepository: FakeDonationRepository(),
      );
      addTearDown(player.dispose);
      addTearDown(library.dispose);

      await tester.pumpWidget(
        RepositoriesScope(
          repositories: repos,
          child: ReproductorScope(
            reproductor: player,
            child: LibraryScope(
              library: library,
              child: const MaterialApp(home: Scaffold(body: NowPlayingModal())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining(song.artistName).first);
      await tester.pumpAndSettle();

      expect(find.byType(BandPublicView), findsOneWidget);
      player.pause();
    },
  );
}
