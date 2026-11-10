import 'dart:math';

import '../data/mock_data.dart';
import '../models/artist.dart';
import '../models/metricas_artista.dart';
import '../models/playback_record.dart';
import '../models/playlist.dart';
import '../models/song.dart';

class MusicRepository {
  final List<Playlist> _playlists = MockData.getInitialPlaylists();

  List<Artist> getArtists() {
    return List.unmodifiable(MockData.artists);
  }

  Artist? getArtistById(String id) {
    return MockData.getArtistById(id);
  }

  List<Song> getSongs() {
    return List.unmodifiable(MockData.songs);
  }

  List<Song> getSongsByArtist(String artistId) {
    return MockData.getSongsByArtist(artistId);
  }

  void addSong(Song song) {
    MockData.songs.insert(0, song);
  }

  List<Playlist> getPlaylists() {
    return List.unmodifiable(_playlists);
  }

  void addPlaylist(Playlist playlist) {
    _playlists.insert(0, playlist);
  }

  bool addSongToPlaylist(String playlistId, Song song) {
    try {
      final playlist = _playlists.firstWhere((p) => p.id == playlistId);
      if (!playlist.songs.any((s) => s.id == song.id)) {
        playlist.songs.add(song);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Genera 50.000 registros de reproducciones para pruebas pesadas de Isolate.
  List<PlaybackRecord> generatePlaybackRecords(
    String artistId, {
    int count = 50000,
  }) {
    final random = Random(42);
    final now = DateTime.now();
    return List<PlaybackRecord>.generate(count, (index) {
      final seconds = 120 + random.nextInt(180); // 2 a 5 minutos
      return PlaybackRecord(
        id: 'rec_$index',
        songId: 'song_${random.nextInt(10)}',
        artistId: artistId,
        durationSeconds: seconds,
        timestamp: now.subtract(Duration(minutes: index % 43200)),
      );
    });
  }

  /// Función matemática pesada diseñada para ejecutarse en segundo plano con [Isolate.run].
  static int calculateTotalMinutes(List<PlaybackRecord> records) {
    int totalSeconds = 0;
    for (int i = 0; i < records.length; i++) {
      totalSeconds += records[i].durationSeconds;
    }
    return totalSeconds ~/ 60;
  }

  /// Procesa métricas avanzadas y ranking de oyentes fieles dentro de [Isolate.run].
  static MetricasArtista calculateAdvancedMetrics(
    List<PlaybackRecord> records,
  ) {
    final totalMinutos = calculateTotalMinutes(records);

    final ranking = [
      OyenteTop(
        nombre: 'Lucas Moreira',
        minutos: (totalMinutos * 0.08).round(),
        ubicacion: 'Buenos Aires',
      ),
      OyenteTop(
        nombre: 'Camila Rossi',
        minutos: (totalMinutos * 0.06).round(),
        ubicacion: 'Córdoba',
      ),
      OyenteTop(
        nombre: 'Martín Galván',
        minutos: (totalMinutos * 0.04).round(),
        ubicacion: 'Rosario',
      ),
    ];

    return MetricasArtista(
      totalMinutos: totalMinutos,
      totalReproducciones: records.length,
      rankingOyentes: ranking,
    );
  }
}
