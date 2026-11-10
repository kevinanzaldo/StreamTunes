import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/mock_data.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/app_repositories.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/repositories/interfaces/song_repository.dart';
import 'package:streamtunes/view_models/artist_detail_view_model.dart';
import 'package:streamtunes/widgets/repositories_scope.dart';

/// Repositorio de temas que falla en la primera llamada y después responde bien.
class _FlakySongRepository extends FakeSongRepository {
  int calls = 0;

  @override
  Future<List<Song>> getSongsByBand(String bandId) async {
    calls++;
    if (calls == 1) throw Exception('sin red');
    return super.getSongsByBand(bandId);
  }
}

ArtistDetailViewModel _crear({SongRepository? songs}) {
  final vm = ArtistDetailViewModel(
    artist: MockData.artists.first,
    songRepository: songs ?? FakeSongRepository(),
    autoEscucharDonaciones: false,
    autoCargarTemas: false,
  );
  addTearDown(vm.dispose);
  return vm;
}

AppRepositories _repositoriosDePrueba() => AppRepositories(
  auth: FakeAuthRepository(),
  songs: FakeSongRepository(),
  bands: FakeBandRepository(),
  playlists: FakePlaylistRepository(),
  donations: FakeDonationRepository(),
);

void main() {
  test('ArtistDetailViewModel: cargarTemas trae solo los de la banda, del más escuchado al menos', () async {
    final vm = _crear();

    expect(vm.songs, isEmpty);
    await vm.cargarTemas();

    expect(vm.cargandoTemas, isFalse);
    expect(vm.errorTemas, isNull);
    expect(vm.songs, isNotEmpty);
    expect(vm.songs.every((s) => s.artistId == vm.artist.id), isTrue);

    final reproducciones = vm.songs.map((s) => s.playCount).toList();
    final ordenadas = List<int>.of(reproducciones)
      ..sort((a, b) => b.compareTo(a));
    expect(reproducciones, equals(ordenadas));
  });

  test('ArtistDetailViewModel: si falla la carga informa el error y reintentar recupera', () async {
    final vm = _crear(songs: _FlakySongRepository());

    await vm.cargarTemas();
    expect(vm.errorTemas, isNotNull);
    expect(vm.cargandoTemas, isFalse);
    expect(vm.songs, isEmpty);

    await vm.cargarTemas();
    expect(vm.errorTemas, isNull);
    expect(vm.songs, isNotEmpty);
  });

  test('ArtistDetailViewModel: no notifica después de dispose si la carga termina tarde', () async {
    final vm = ArtistDetailViewModel(
      artist: MockData.artists.first,
      songRepository: FakeSongRepository(),
      autoEscucharDonaciones: false,
    );
    vm.dispose();

    // Deja correr la carga y la consulta de cámara que arrancó el constructor.
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  testWidgets('RepositoriesScope: entrega los repositorios inyectados', (
    WidgetTester tester,
  ) async {
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

  testWidgets(
    'RepositoriesScope: sin scope usa un respaldo en memoria compartido',
    (WidgetTester tester) async {
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
    },
  );
}
