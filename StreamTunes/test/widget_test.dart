import 'package:flutter_test/flutter_test.dart';
import 'package:changenotifier_ejercicio/main.dart';
import 'package:changenotifier_ejercicio/state/player_model.dart';
import 'package:changenotifier_ejercicio/state/library_model.dart';
import 'package:changenotifier_ejercicio/data/mock_data.dart';

void main() {
  testWidgets('StreamTunesApp smoke test y verificación de navegación principal', (WidgetTester tester) async {
    // Construir la aplicación StreamTunes y renderizar primer frame
    await tester.pumpWidget(const StreamTunesApp());
    await tester.pumpAndSettle();

    // Verificar que el título de la plataforma y secciones clave estén en pantalla
    expect(find.text('StreamTunes'), findsOneWidget);
    expect(find.text('Últimos Lanzamientos'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Tu Biblioteca'), findsOneWidget);
  });

  test('PlayerModel playSong y togglePlay actualizan estado reactivo', () {
    final player = PlayerModel();
    final song = MockData.songs.first;

    expect(player.hasSong, isFalse);
    expect(player.isPlaying, isFalse);

    // Reproducir canción
    player.playSong(song);
    expect(player.hasSong, isTrue);
    expect(player.currentSong?.id, equals(song.id));
    expect(player.isPlaying, isTrue);

    // Pausar
    player.togglePlay();
    expect(player.isPlaying, isFalse);

    // Reanudar
    player.togglePlay();
    expect(player.isPlaying, isTrue);

    player.dispose();
  });

  test('LibraryModel gestiona favoritos y creación de playlists', () {
    final library = LibraryModel();
    final song = MockData.songs[1];

    final initialCount = library.favoriteSongs.length;
    final isFavInitially = library.isFavorite(song);

    // Conmutar favorito
    library.toggleFavorite(song);
    expect(library.isFavorite(song), isNot(isFavInitially));
    expect(library.favoriteSongs.length, isNot(equals(initialCount)));

    // Crear playlist
    final initialPlaylistsCount = library.playlists.length;
    library.createPlaylist('Mi Lista Indie', description: 'Favoritas de rock');
    expect(library.playlists.length, equals(initialPlaylistsCount + 1));
    expect(library.playlists.first.name, equals('Mi Lista Indie'));

    // Agregar canción a la playlist creada
    final createdId = library.playlists.first.id;
    final added = library.addSongToPlaylist(createdId, song);
    expect(added, isTrue);
    expect(library.playlists.first.songs.length, equals(1));
  });
}
