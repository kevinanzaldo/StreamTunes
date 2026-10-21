import 'package:changenotifier_ejercicio/data/mock_data.dart';
import 'package:changenotifier_ejercicio/main.dart';
import 'package:changenotifier_ejercicio/state/library_model.dart';
import 'package:changenotifier_ejercicio/state/player_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StreamTunesApp muestra el inicio y la barra de navegación', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StreamTunesApp());
    await tester.pumpAndSettle();

    expect(find.text('StreamTunes'), findsOneWidget);
    expect(find.text('Bandas'), findsOneWidget);
    expect(find.text('Últimos lanzamientos'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Subir'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
  });

  test('PlayerModel playSong y togglePlay actualizan estado reactivo', () {
    final player = PlayerModel();
    final song = MockData.songs.first;

    expect(player.hasSong, isFalse);
    expect(player.isPlaying, isFalse);

    player.playSong(song);
    expect(player.hasSong, isTrue);
    expect(player.currentSong?.id, equals(song.id));
    expect(player.isPlaying, isTrue);

    player.togglePlay();
    expect(player.isPlaying, isFalse);

    player.togglePlay();
    expect(player.isPlaying, isTrue);

    player.dispose();
  });

  test('LibraryModel gestiona favoritos y creación de playlists', () {
    final library = LibraryModel();
    final song = MockData.songs[1];

    final initialCount = library.favoriteSongs.length;
    final isFavInitially = library.isFavorite(song);

    library.toggleFavorite(song);
    expect(library.isFavorite(song), isNot(isFavInitially));
    expect(library.favoriteSongs.length, isNot(equals(initialCount)));

    final initialPlaylistsCount = library.playlists.length;
    library.createPlaylist('Mi Lista Indie', description: 'Favoritas de rock');
    expect(library.playlists.length, equals(initialPlaylistsCount + 1));
    expect(library.playlists.first.name, equals('Mi Lista Indie'));

    final createdId = library.playlists.first.id;
    final added = library.addSongToPlaylist(createdId, song);
    expect(added, isTrue);
    expect(library.playlists.first.songs.length, equals(1));
  });
}
