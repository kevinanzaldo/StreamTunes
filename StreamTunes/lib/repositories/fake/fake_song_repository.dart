import '../../data/mock_data.dart';
import '../../models/song.dart';
import '../interfaces/song_repository.dart';

/// Implementación en memoria basada en `MockData` (tests y modo demo).
class FakeSongRepository implements SongRepository {
  @override
  Future<List<Song>> getLatestSongs({int limit = 50}) async {
    final sorted = List<Song>.of(MockData.songs)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return List.unmodifiable(sorted.take(limit));
  }

  @override
  Future<List<Song>> getSongsByBand(String bandId) async {
    return MockData.getSongsByArtist(bandId);
  }

  @override
  Future<Song> addSong(Song song, {String? albumId}) async {
    MockData.songs.insert(0, song);
    return song;
  }

  final List<Map<String, dynamic>> recordedPlayEvents = [];

  @override
  Future<void> recordPlayEvent({
    required String songId,
    required String bandId,
    required int secondsListened,
    String? userId,
  }) async {
    recordedPlayEvents.add({
      'song_id': songId,
      'band_id': bandId,
      'seconds_listened': secondsListened,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getPlayEventsByBand(String bandId) async {
    return List<Map<String, dynamic>>.unmodifiable(
      recordedPlayEvents.where((event) => event['band_id'] == bandId),
    );
  }
}
