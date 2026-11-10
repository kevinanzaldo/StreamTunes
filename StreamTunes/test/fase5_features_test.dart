import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/mock_data.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/services/audio_service.dart';
import 'package:streamtunes/view_models/home_view_model.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/reproductor_view_model.dart';
import 'package:streamtunes/views/home_view.dart';
import 'package:streamtunes/widgets/library_scope.dart';
import 'package:streamtunes/widgets/reproductor_scope.dart';
import 'package:streamtunes/widgets/song_tile.dart';

void main() {
  test('ReproductorViewModel + AudioService: pausa y reanuda ante interrupciones de llamada', () {
    bool interrupcionPausa = false;
    bool interrupcionReanuda = false;

    late final ReproductorViewModel repVm;
    final audioService = AudioService(
      reanudarTrasLlamada: true,
      onInterruptionPause: () {
        interrupcionPausa = true;
        repVm.pause();
      },
      onInterruptionResume: () {
        interrupcionReanuda = true;
        repVm.resume();
      },
    );

    final songRepo = FakeSongRepository();
    repVm = ReproductorViewModel(
      audioService: audioService,
      songRepository: songRepo,
    );

    final song = MockData.songs.first;
    repVm.play(song);
    expect(repVm.isPlaying, isTrue);

    // Simular llamada entrante
    audioService.onInterruptionPause?.call();
    expect(interrupcionPausa, isTrue);
    expect(repVm.isPlaying, isFalse);

    // Simular fin de llamada
    audioService.onInterruptionResume?.call();
    expect(interrupcionReanuda, isTrue);
    expect(repVm.isPlaying, isTrue);

    repVm.dispose();
  });

  test('HomeViewModel: buscador y filtro por género', () async {
    final songRepo = FakeSongRepository();
    final bandRepo = FakeBandRepository();
    final vm = HomeViewModel(
      songRepository: songRepo,
      bandRepository: bandRepo,
    );

    await vm.load();
    expect(vm.latestSongs, isNotEmpty);
    final total = vm.latestSongs.length;

    // Búsqueda por título
    final targetSong = vm.latestSongs.first;
    vm.setSearchQuery(targetSong.title);
    expect(vm.filteredSongs, hasLength(greaterThanOrEqualTo(1)));
    expect(vm.filteredSongs.first.title, targetSong.title);

    // Búsqueda sin coincidencias
    vm.setSearchQuery('inexistente_123456');
    expect(vm.filteredSongs, isEmpty);

    // Limpiar búsqueda y filtrar por género
    vm.setSearchQuery('');
    expect(vm.filteredSongs, hasLength(total));

    if (vm.availableGenres.isNotEmpty) {
      final genre = vm.availableGenres.first;
      vm.selectGenre(genre);
      expect(
        vm.filteredSongs.every(
          (s) => s.genre.toLowerCase() == genre.toLowerCase(),
        ),
        isTrue,
      );

      // Deseleccionar género
      vm.selectGenre('Todos');
      expect(vm.filteredSongs, hasLength(total));
    }

    vm.dispose();
  });

  testWidgets('HomeView: renderiza buscador y chips de género', (
    WidgetTester tester,
  ) async {
    final songRepo = FakeSongRepository();
    final bandRepo = FakeBandRepository();
    final vm = HomeViewModel(
      songRepository: songRepo,
      bandRepository: bandRepo,
    );

    final player = ReproductorViewModel();
    final library = LibraryViewModel(
      playlistRepository: FakePlaylistRepository(),
      donationRepository: FakeDonationRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReproductorScope(
          reproductor: player,
          child: LibraryScope(
            library: library,
            child: HomeView(viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_search_input')), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);

    player.dispose();
    library.dispose();
    vm.dispose();
  });

  testWidgets(
    'SongTile: permite crear nueva playlist desde el diálogo de agregar',
    (WidgetTester tester) async {
      final song = MockData.songs.first;
      final libRepo = FakePlaylistRepository();
      final lib = LibraryViewModel(
        playlistRepository: libRepo,
        donationRepository: FakeDonationRepository(),
      );
      final player = ReproductorViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReproductorScope(
              reproductor: player,
              child: LibraryScope(
                library: lib,
                child: SongTile(song: song),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tocar botón agregar
      await tester.tap(find.byIcon(Icons.playlist_add));
      await tester.pumpAndSettle();

      // Debe aparecer opción "Nueva playlist"
      expect(find.text('Nueva playlist'), findsOneWidget);

      // Tocar en "Nueva playlist"
      await tester.tap(find.text('Nueva playlist'));
      await tester.pumpAndSettle();

      // Formulario de nombre
      expect(find.text('Nueva Playlist'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Mi Lista Test');
      await tester.tap(find.text('Crear y Guardar'));
      await tester.pumpAndSettle();

      expect(lib.playlists.any((p) => p.name == 'Mi Lista Test'), isTrue);

      player.dispose();
      lib.dispose();
    },
  );
}
