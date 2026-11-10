import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/mock_data.dart';
import 'package:streamtunes/models/donation.dart';
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
  Future<void> removeSong(String playlistId, String songId) async =>
      throw UnimplementedError();
}

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
      final playlist = vm.playlists.firstWhere((p) => p.id == 'pl_3');
      final antes = playlist.songCount;
      final tema = MockData.songs[4]; // no está en 'pl_3'

      expect(await vm.addSongToPlaylist('pl_3', tema), isTrue);
      expect(playlist.songCount, antes + 1);

      // Repetido: devuelve false pero no es un error
      expect(await vm.addSongToPlaylist('pl_3', tema), isFalse);
      expect(playlist.songCount, antes + 1);
      expect(vm.error, isNull);

      await vm.removeSongFromPlaylist('pl_3', tema.id);
      expect(playlist.songCount, antes);
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
    expect(await vm.addSongToPlaylist(playlist.id, MockData.songs[4]), isFalse);
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

  test(
    'LibraryViewModel: recordDonation guarda la donación y suma el total',
    () async {
      final vm = _crear();
      await vm.load();
      final artist = MockData.artists.first;
      final inicial = artist.donationsCollected;
      addTearDown(() => artist.donationsCollected = inicial);

      final ok = await vm.recordDonation(
        Donation(
          id: 'don_test',
          artistId: artist.id,
          artistName: artist.name,
          amount: 1500,
          paymentMethod: 'TestPay',
        ),
      );

      expect(ok, isTrue);
      expect(vm.donations.first.id, 'don_test');
      expect(vm.totalDonatedAmount, 1500);
      expect(artist.donationsCollected, inicial + 1500);
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
