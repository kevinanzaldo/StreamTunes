import '../../models/song.dart';

/// Acceso a los temas. Implementaciones: `FakeSongRepository` (tests/demo)
/// y, más adelante, `SupabaseSongRepository`.
abstract interface class SongRepository {
  /// Últimos lanzamientos de bandas aprobadas, del más nuevo al más viejo.
  Future<List<Song>> getLatestSongs({int limit = 50});

  Future<List<Song>> getSongsByBand(String bandId);

  /// Publica un tema. Puede lanzar si se supera el cupo (20 temas por banda).
  Future<Song> addSong(Song song, {String? albumId});

  /// Registra un evento de reproducción en `play_events` con los segundos escuchados.
  Future<void> recordPlayEvent({
    required String songId,
    required String bandId,
    required int secondsListened,
    String? userId,
  });
}
