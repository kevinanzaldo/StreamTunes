import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/repositories/interfaces/song_repository.dart';
import 'package:streamtunes/view_models/home_view_model.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/reproductor_view_model.dart';
import 'package:streamtunes/views/home_view.dart';
import 'package:streamtunes/widgets/library_scope.dart';
import 'package:streamtunes/widgets/reproductor_scope.dart';

/// Repositorio que falla en la primera llamada y después responde bien.
class _FlakySongRepository implements SongRepository {
  final FakeSongRepository _delegate = FakeSongRepository();
  int calls = 0;

  @override
  Future<List<Song>> getLatestSongs({int limit = 50}) async {
    calls++;
    if (calls == 1) throw Exception('sin red');
    return _delegate.getLatestSongs(limit: limit);
  }

  @override
  Future<List<Song>> getSongsByBand(String bandId) =>
      _delegate.getSongsByBand(bandId);

  @override
  Future<Song> addSong(Song song, {String? albumId}) =>
      _delegate.addSong(song, albumId: albumId);

  @override
  Future<void> recordPlayEvent({
    required String songId,
    required String bandId,
    required int secondsListened,
    String? userId,
  }) => _delegate.recordPlayEvent(
    songId: songId,
    bandId: bandId,
    secondsListened: secondsListened,
    userId: userId,
  );

  @override
  Future<List<Map<String, dynamic>>> getPlayEventsByBand(String bandId) =>
      _delegate.getPlayEventsByBand(bandId);
}

HomeViewModel _crearViewModel({SongRepository? songs}) {
  return HomeViewModel(
    songRepository: songs ?? FakeSongRepository(),
    bandRepository: FakeBandRepository(),
  );
}

void main() {
  test(
    'HomeViewModel: load() pasa a ready con bandas y temas por fecha',
    () async {
      final vm = _crearViewModel();
      addTearDown(vm.dispose);

      expect(vm.status, HomeStatus.loading);
      await vm.load();

      expect(vm.status, HomeStatus.ready);
      expect(vm.bands, isNotEmpty);
      expect(vm.filteredSongs, isNotEmpty);

      final fechas = vm.filteredSongs.map((s) => s.uploadedAt).toList();
      final ordenadas = List<DateTime>.of(fechas)
        ..sort((a, b) => b.compareTo(a));
      expect(fechas, equals(ordenadas));
    },
  );

  test(
    'HomeViewModel: si el repositorio falla pasa a error y reintentar recupera',
    () async {
      final vm = _crearViewModel(songs: _FlakySongRepository());
      addTearDown(vm.dispose);

      await vm.load();
      expect(vm.status, HomeStatus.error);

      await vm.load();
      expect(vm.status, HomeStatus.ready);
      expect(vm.filteredSongs, isNotEmpty);
    },
  );

  test(
    'HomeViewModel: filtrado de bandas y canciones por búsqueda y género',
    () async {
      final vm = _crearViewModel();
      addTearDown(vm.dispose);
      await vm.load();

      expect(vm.bands, isNotEmpty);
      expect(vm.filteredSongs, isNotEmpty);

      vm.setSearchQuery('Subterráneos');
      expect(vm.filteredBands, hasLength(1));
      expect(vm.filteredBands.first.name, 'Los Subterráneos');

      vm.setSearchQuery('');
      expect(vm.filteredBands, vm.bands);
    },
  );

  testWidgets(
    'HomeView: muestra error con botón Reintentar y luego el contenido',
    (WidgetTester tester) async {
      final vm = _crearViewModel(songs: _FlakySongRepository());
      final player = ReproductorViewModel();
      final library = LibraryViewModel(
        playlistRepository: FakePlaylistRepository(),
        donationRepository: FakeDonationRepository(),
      );
      addTearDown(vm.dispose);
      addTearDown(player.dispose);
      addTearDown(library.dispose);

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

      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Últimos lanzamientos'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('Bandas'), findsOneWidget);
      expect(find.text('Últimos lanzamientos'), findsOneWidget);
    },
  );

  test(
    'HomeViewModel: filteredBands busca bandas por nombre, género o bio',
    () async {
      final vm = _crearViewModel();
      addTearDown(vm.dispose);
      await vm.load();

      expect(vm.bands, isNotEmpty);

      // Búsqueda por nombre de banda
      vm.setSearchQuery('Subterráneos');
      expect(vm.filteredBands, hasLength(1));
      expect(vm.filteredBands.single.name, 'Los Subterráneos');

      // Búsqueda por género de banda
      vm.setSearchQuery('Synthwave');
      expect(vm.filteredBands, hasLength(1));
      expect(vm.filteredBands.single.name, 'Banda Fractal');

      // Búsqueda sin coincidencias
      vm.setSearchQuery('NombreInexistente123');
      expect(vm.filteredBands, isEmpty);

      // Limpiar búsqueda
      vm.setSearchQuery('');
      expect(vm.filteredBands, equals(vm.bands));
    },
  );
}
