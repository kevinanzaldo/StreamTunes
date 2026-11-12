import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/models/playlist.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/interfaces/playlist_repository.dart';
import 'package:streamtunes/view_models/library_view_model.dart';

/// Repositorio de playlists que falla en las escrituras.
class _ThrowingPlaylistRepository extends FakePlaylistRepository {
  @override
  Future<Playlist> createPlaylist({
    required String name,
    String description = '',
  }) async => throw Exception('sin sesión');

  @override
  Future<void> addSong(String playlistId, Song song) async =>
      throw Exception('sin permisos');
}

/// Repositorio cuya lectura falla (por ejemplo, sin red).
class _UnreachablePlaylistRepository implements PlaylistRepository {
  @override
  Future<List<Playlist>> getMyPlaylists() async => throw Exception('sin red');

  @override
  Future<Playlist> createPlaylist({
    required String name,
    String description = '',
  }) async => throw UnimplementedError();

  @override
  Future<void> addSong(String playlistId, Song song) async =>
      throw UnimplementedError();

  @override
  Future<Playlist> updatePlaylist(
    String playlistId, {
    required String name,
    String? description,
  }) async => throw UnimplementedError();

  @override
  Future<void> deletePlaylist(String playlistId) async =>
      throw UnimplementedError();

  @override
  Future<void> removeSong(String playlistId, String songId) async =>
      throw UnimplementedError();
}

Song _sampleSong({String id = 'song_sample_lib'}) => Song(
  id: id,
  title: 'Tema Test',
  artistId: 'artist_1',
  artistName: 'Los Subterráneos',
  album: 'Album Test',
  duration: const Duration(minutes: 3),
  genre: 'Rock',
  icon: Icons.music_note,
  gradientColors: const [Colors.red, Colors.blue],
  uploadedAt: DateTime(2026, 1, 1),
);

LibraryViewModel _crear({PlaylistRepository? playlists}) {
  final vm = LibraryViewModel(
    playlistRepository: playlists ?? FakePlaylistRepository(),
    donationRepository: FakeDonationRepository(),
    autoCargar: false,
  );
  addTearDown(vm.dispose);
  return vm;
}

void main() {
  test('LibraryViewModel: load() trae las playlists del repositorio', () async {
    final vm = _crear();

    expect(vm.playlists, isEmpty);
    await vm.load();

    expect(vm.isLoading, isFalse);
    expect(vm.loadFailed, isFalse);
    expect(vm.playlists, isNotEmpty);
  });

  test('LibraryViewModel: createPlaylist agrega al inicio y rechaza nombres vacíos', () async {
    final vm = _crear();
    await vm.load();
    final antes = vm.playlists.length;

    expect(await vm.createPlaylist('   '), isFalse);
    expect(vm.playlists, hasLength(antes));

    expect(await vm.createPlaylist('  Para el micro  '), isTrue);
    expect(vm.playlists, hasLength(antes + 1));
    expect(vm.playlists.first.name, 'Para el micro');
  });

  test(
    'LibraryViewModel: addSongToPlaylist agrega el tema una sola vez',
    () async {
      final vm = _crear();
      await vm.load();
      final playlist = vm.playlists.first;
      final antes = playlist.songCount;
      final tema = _sampleSong(id: 'song_test_unique');

      expect(await vm.addSongToPlaylist(playlist.id, tema), isTrue);
      expect(playlist.songCount, antes + 1);

      // Repetido: devuelve false pero no es un error
      expect(await vm.addSongToPlaylist(playlist.id, tema), isFalse);
      expect(playlist.songCount, antes + 1);
      expect(vm.error, isNull);
    },
  );

  test('LibraryViewModel: si el repositorio falla informa el error y no cambia la lista', () async {
    final vm = _crear(playlists: _ThrowingPlaylistRepository());
    await vm.load();
    final antes = vm.playlists.length;

    expect(await vm.createPlaylist('Nueva'), isFalse);
    expect(vm.error, isNotNull);
    expect(vm.playlists, hasLength(antes));

    final playlist = vm.playlists.first;
    final songCount = playlist.songCount;
    expect(await vm.addSongToPlaylist(playlist.id, _sampleSong()), isFalse);
    expect(vm.error, isNotNull);
    expect(playlist.songCount, songCount);
  });

  test(
    'LibraryViewModel: si la carga falla marca loadFailed y deja de cargar',
    () async {
      final vm = _crear(playlists: _UnreachablePlaylistRepository());

      await vm.load();
      expect(vm.loadFailed, isTrue);
      expect(vm.isLoading, isFalse);
      expect(vm.error, isNotNull);
    },
  );

  test('LibraryViewModel: updatePlaylist actualiza el nombre', () async {
    final vm = _crear();
    await vm.load();
    final target = vm.playlists.first;

    expect(await vm.updatePlaylist(target.id, name: 'Nuevo Nombre'), isTrue);
    expect(
      vm.playlists.firstWhere((p) => p.id == target.id).name,
      'Nuevo Nombre',
    );

    // Nombre vacío debe rechazarse
    expect(await vm.updatePlaylist(target.id, name: '   '), isFalse);
  });

  test('LibraryViewModel: deletePlaylist elimina la playlist', () async {
    final vm = _crear();
    await vm.load();
    final target = vm.playlists.first;
    final totalAntes = vm.playlists.length;

    expect(await vm.deletePlaylist(target.id), isTrue);
    expect(vm.playlists.length, totalAntes - 1);
    expect(vm.playlists.any((p) => p.id == target.id), isFalse);
  });

  test(
    'LibraryViewModel: removeSongFromPlaylist quita el tema de la lista',
    () async {
      final vm = _crear();
      await vm.load();
      final playlist = vm.playlists.first;
      final tema = _sampleSong(id: 'song_to_remove');
      await vm.addSongToPlaylist(playlist.id, tema);
      expect(playlist.songs.any((s) => s.id == tema.id), isTrue);

      expect(await vm.removeSongFromPlaylist(playlist.id, tema.id), isTrue);
      expect(playlist.songs.any((s) => s.id == tema.id), isFalse);
    },
  );

  test('LibraryViewModel: no notifica después de dispose si la carga termina tarde', () async {
    final vm = LibraryViewModel(
      playlistRepository: FakePlaylistRepository(),
      donationRepository: FakeDonationRepository(),
    );
    vm.dispose();

    // Deja correr la carga que arrancó el constructor: no debe lanzar.
    await Future<void>.delayed(Duration.zero);
  });
}
