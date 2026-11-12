import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/interfaces/song_repository.dart';
import 'package:streamtunes/repositories/interfaces/storage_repository.dart';
import 'package:streamtunes/services/dispositivo_capacidades.dart';
import 'package:streamtunes/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/reproductor_view_model.dart';
import 'package:streamtunes/views/band_dashboard_view.dart';
import 'package:streamtunes/widgets/library_scope.dart';
import 'package:streamtunes/widgets/reproductor_scope.dart';

Band _testBand({
  String id = 'band_dash',
  String name = 'Los Paneleros',
  BandStatus status = BandStatus.approved,
}) {
  return Band(
    id: id,
    slug: 'los-paneleros',
    name: name,
    bio: 'Banda para pruebas del panel.',
    genre: 'Indie Rock',
    location: 'Rosario',
    donationGoal: 20000,
    donationsCollected: 4500,
    status: status,
    createdBy: 'user_1',
    createdAt: DateTime(2026, 1, 1),
  );
}

class _MockSongRepo implements SongRepository {
  bool fail = false;
  List<Map<String, dynamic>> playEvents = const [];

  @override
  Future<List<Song>> getLatestSongs({int limit = 50}) async => [];

  @override
  Future<List<Song>> getSongsByBand(String bandId) async {
    if (fail) throw Exception('falla');
    return [
      Song(
        id: 's1',
        title: 'Canción del Panel',
        artistId: bandId,
        artistName: 'Los Paneleros',
        album: 'Demo',
        duration: const Duration(minutes: 3),
        genre: 'Indie',
        icon: Icons.music_note,
        gradientColors: const [Colors.blue, Colors.purple],
        playCount: 150,
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
      playEvents;
}

void main() {
  test('BandDashboardViewModel: load carga temas y calcula cupo', () async {
    final repo = _MockSongRepo();
    final vm = BandDashboardViewModel(
      band: _testBand(),
      songRepository: repo,
      donationRepository: FakeDonationRepository(),
    );

    await vm.load();

    expect(vm.isLoading, isFalse);
    expect(vm.error, isNull);
    expect(vm.songCount, 1);
    expect(vm.songs.first.title, 'Canción del Panel');
  });

  test(
    'BandDashboardViewModel: calculateMetrics ejecuta Isolate y carga métricas',
    () async {
      final vm = BandDashboardViewModel(
        band: _testBand(),
        songRepository: _MockSongRepo(),
        donationRepository: FakeDonationRepository(),
      );

      await vm.calculateMetrics();

      expect(vm.isCalculatingStats, isFalse);
      expect(vm.statsError, isNull);
      expect(vm.metrics, isNotNull);
      expect(vm.metrics!.totalReproducciones, 0);
    },
  );

  testWidgets('BandDashboardView: muestra tarjetas de resumen y temas', (
    tester,
  ) async {
    final vm = BandDashboardViewModel(
      band: _testBand(),
      songRepository: _MockSongRepo(),
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
            child: BandDashboardView(band: _testBand(), viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Panel: Los Paneleros'), findsOneWidget);
    expect(find.text('Cupo de temas'), findsOneWidget);
    expect(find.text('1 / 20'), findsOneWidget);
    expect(find.text('Canción del Panel'), findsOneWidget);
    expect(find.text('150 plays'), findsOneWidget);
  });

  testWidgets('BandDashboardView: banner de estado cuando está pendiente', (
    tester,
  ) async {
    final pendingBand = _testBand(status: BandStatus.pending);
    final vm = BandDashboardViewModel(
      band: pendingBand,
      songRepository: _MockSongRepo(),
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
            child: BandDashboardView(band: pendingBand, viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Banda pendiente de aprobación'),
      findsOneWidget,
    );
  });

  testWidgets('BandDashboardView: renderiza métricas cuando están calculadas', (
    tester,
  ) async {
    final vm = BandDashboardViewModel(
      band: _testBand(),
      songRepository: _MockSongRepo(),
      donationRepository: FakeDonationRepository(),
    );
    await vm.load();
    await tester.runAsync(() async {
      await vm.calculateMetrics();
    });

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
            child: BandDashboardView(band: _testBand(), viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Top Fans del período:'), findsOneWidget);
    expect(
      find.text(
        'Todavía no hay reproducciones registradas para tu banda. ¡Compartí tu perfil para empezar a sumar minutos!',
      ),
      findsOneWidget,
    );
    expect(find.text('Actualizar estadísticas'), findsOneWidget);
  });

  test('procesarMetricasReales formatea series reales sin datos sintéticos ni eventos falsos', () {
    const input = SeriesProcesadasInput(
      playEvents: [
        {
          'song_id': 's1',
          'user_id': 'user_ana',
          'seconds_listened': 300,
          'profiles': {'display_name': 'Ana Oyente', 'is_public_profile': true},
        },
      ],
      songTitlesById: {'s1': 'Tema Alfa'},
    );

    final metrics = procesarMetricasReales(input);

    expect(metrics.totalReproducciones, 1);
    expect(metrics.totalMinutos, 5);
    expect(metrics.topTemas, hasLength(1));
    expect(metrics.topTemas.first.titulo, 'Tema Alfa');
    expect(metrics.rankingOyentes, hasLength(1));
    expect(metrics.rankingOyentes.first.nombre, 'Ana Oyente');
  });

  test('BandDashboardViewModel.calculateMetrics agrega play_events reales por user_id respetando privacidad', () async {
    final repo = _MockSongRepo()
      ..playEvents = [
        {
          'song_id': 's1',
          'user_id': 'user_ana',
          'seconds_listened': 240,
          'profiles': {'display_name': 'Ana Oyente', 'is_public_profile': true},
        },
        {
          'song_id': 's1',
          'user_id': 'user_ana',
          'seconds_listened': 180,
          'profiles': {'display_name': 'Ana Oyente', 'is_public_profile': true},
        },
        {
          'song_id': 's1',
          'user_id': 'user_beto',
          'seconds_listened': 120,
          'profiles': {
            'display_name': 'Beto Oyente',
            'is_public_profile': true,
          },
        },
      ];

    final vm = BandDashboardViewModel(
      band: _testBand(),
      songRepository: repo,
      donationRepository: FakeDonationRepository(),
    );
    await vm.load();
    await vm.calculateMetrics();

    expect(vm.metrics, isNotNull);
    expect(vm.metrics!.rankingOyentes, hasLength(2));
    expect(vm.metrics!.rankingOyentes.first.nombre, 'Ana Oyente');
    expect(vm.metrics!.rankingOyentes.first.minutos, 7);
    expect(vm.metrics!.rankingOyentes.last.nombre, 'Beto Oyente');
    expect(vm.metrics!.rankingOyentes.last.minutos, 2);
  });

  test('BandDashboardViewModel: updateBandProfile no guarda data URI si falla portada en Storage real', () async {
    final bandRepo = FakeBandRepository();
    final band = _testBand();
    await bandRepo.createBand(band);
    final vm = BandDashboardViewModel(
      band: band,
      songRepository: _MockSongRepo(),
      donationRepository: FakeDonationRepository(),
      bandRepository: bandRepo,
      storageRepository: _ThrowingRealStorageRepo(),
    );

    final result = await vm.updateBandProfile(
      currentBand: band,
      name: 'Los Paneleros Editados',
      genre: 'Rock',
      location: 'Rosario',
      bio: 'Nueva bio',
      donationGoal: 25000,
      selectedImage: SelectedImageFile(
        name: 'portada.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );

    expect(result.coverFailed, isTrue);
    final updated = await bandRepo.getBandById(band.id);
    expect(updated?.coverUrl, isNull);
  });
}

class _ThrowingRealStorageRepo implements StorageRepository {
  @override
  bool get isMock => false;

  @override
  Future<String> uploadAudio({
    required String bandId,
    required String songId,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async => '$bandId/$songId.mp3';

  @override
  Future<String> uploadCover({
    required String bandId,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async => throw Exception('bucket error');

  @override
  String getAudioPublicUrl(String path) =>
      'https://example.supabase.co/audio/$path';

  @override
  String getCoverPublicUrl(String path) =>
      'https://example.supabase.co/covers/$path';
}
