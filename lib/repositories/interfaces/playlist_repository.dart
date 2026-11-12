import '../../models/playlist.dart';
import '../../models/song.dart';

/// Acceso a las playlists del usuario. Implementaciones: `FakePlaylistRepository`
/// (tests/demo) y `SupabasePlaylistRepository`.
abstract interface class PlaylistRepository {
  /// Playlists del usuario actual, de la más nueva a la más vieja.
  /// Sin sesión devuelve una lista vacía.
  Future<List<Playlist>> getMyPlaylists();

  /// Crea una playlist propia. Lanza si no hay sesión.
  Future<Playlist> createPlaylist({
    required String name,
    String description = '',
  });

  /// Agrega un tema a la playlist. Si ya estaba, no hace nada.
  Future<void> addSong(String playlistId, Song song);

  /// Modifica el nombre y/o descripción de una playlist.
  Future<Playlist> updatePlaylist(
    String playlistId, {
    required String name,
    String? description,
  });

  /// Elimina una playlist.
  Future<void> deletePlaylist(String playlistId);

  Future<void> removeSong(String playlistId, String songId);
}
