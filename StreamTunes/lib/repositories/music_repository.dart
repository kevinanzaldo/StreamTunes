import 'dart:math';

import '../data/mock_data.dart';
import '../models/artist.dart';
import '../models/metricas_artista.dart';
import '../models/playback_record.dart';
import '../models/playlist.dart';
import '../models/song.dart';

/// Mensaje liviano serializable para delegar tanto la generación de eventos
/// sintéticos como las agregaciones pesadas al [Isolate] secundario.
class MetricsComputeInput {
  final String artistId;
  final Map<String, String> songTitlesById;
  final List<Map<String, dynamic>> playEvents;
  final int count;
  final int seed;
  final int referenceEpochMs;

  const MetricsComputeInput({
    required this.artistId,
    this.songTitlesById = const {},
    this.playEvents = const [],
    this.count = 50000,
    this.seed = 42,
    this.referenceEpochMs = 1775001600000,
  });
}

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

  /// Genera [count] registros de reproducción determinísticos con [seed].
  /// Diseñado para ejecutarse dentro del Isolate secundario.
  static List<PlaybackRecord> generatePlaybackRecordsForSeed({
    required String artistId,
    List<String> songIds = const [],
    int count = 50000,
    int seed = 42,
    int referenceEpochMs = 1775001600000,
  }) {
    final random = Random(seed);
    final baseTime = DateTime.fromMillisecondsSinceEpoch(
      referenceEpochMs,
      isUtc: true,
    );
    final effectiveSongIds = songIds.isNotEmpty
        ? songIds
        : const [
            'tema_1',
            'tema_2',
            'tema_3',
            'tema_4',
            'tema_5',
            'tema_6',
            'tema_7',
            'tema_8',
            'tema_9',
            'tema_10',
          ];

    return List<PlaybackRecord>.generate(count, (index) {
      final seconds = 120 + random.nextInt(180); // 2 a 5 minutos
      final songId = effectiveSongIds[random.nextInt(effectiveSongIds.length)];
      final daysAgo = random.nextInt(30);
      final minutesOffset = random.nextInt(1440);
      return PlaybackRecord(
        id: 'rec_$index',
        songId: songId,
        artistId: artistId,
        durationSeconds: seconds,
        timestamp: baseTime.subtract(
          Duration(days: daysAgo, minutes: minutesOffset),
        ),
      );
    });
  }

  /// Genera los 50.000 eventos sintéticos y calcula agregaciones reales
  /// (por tema, por día y ranking real desde [playEvents]) íntegramente
  /// dentro del [Isolate] / `compute`.
  static MetricasArtista generateAndCalculateMetrics(
    MetricsComputeInput input,
  ) {
    final sortedSongIds = input.songTitlesById.keys.toList()..sort();
    final records = generatePlaybackRecordsForSeed(
      artistId: input.artistId,
      songIds: sortedSongIds,
      count: input.count,
      seed: input.seed,
      referenceEpochMs: input.referenceEpochMs,
    );

    final baseMetrics = calculateAdvancedMetrics(
      records,
      songTitlesById: input.songTitlesById,
    );
    final realRanking = aggregateListenersFromPlayEvents(input.playEvents);

    return MetricasArtista(
      totalMinutos: baseMetrics.totalMinutos,
      totalReproducciones: baseMetrics.totalReproducciones,
      rankingOyentes: realRanking,
      topTemas: baseMetrics.topTemas,
      reproduccionesPorDia: baseMetrics.reproduccionesPorDia,
      totalEventosReales: input.playEvents.length,
      esSimulacion: true,
    );
  }

  /// Función matemática pesada diseñada para ejecutarse en segundo plano con [Isolate.run].
  static int calculateTotalMinutes(List<PlaybackRecord> records) {
    int totalSeconds = 0;
    for (int i = 0; i < records.length; i++) {
      totalSeconds += records[i].durationSeconds;
    }
    return totalSeconds ~/ 60;
  }

  /// Agrega reproducciones por tema y por día sobre [records] dentro del Isolate.
  /// No inventa nombres de oyentes: el ranking proviene solo de `play_events` reales.
  static MetricasArtista calculateAdvancedMetrics(
    List<PlaybackRecord> records, {
    Map<String, String> songTitlesById = const {},
  }) {
    int totalSeconds = 0;
    final playsBySong = <String, int>{};
    final secondsBySong = <String, int>{};
    final playsByDay = <String, int>{};
    final secondsByDay = <String, int>{};

    for (int i = 0; i < records.length; i++) {
      final rec = records[i];
      totalSeconds += rec.durationSeconds;

      playsBySong[rec.songId] = (playsBySong[rec.songId] ?? 0) + 1;
      secondsBySong[rec.songId] =
          (secondsBySong[rec.songId] ?? 0) + rec.durationSeconds;

      final dayKey = _formatDateKey(rec.timestamp);
      playsByDay[dayKey] = (playsByDay[dayKey] ?? 0) + 1;
      secondsByDay[dayKey] = (secondsByDay[dayKey] ?? 0) + rec.durationSeconds;
    }

    final topTemas =
        playsBySong.entries
            .map(
              (entry) => TemaMetrica(
                songId: entry.key,
                titulo: songTitlesById[entry.key] ?? entry.key,
                reproducciones: entry.value,
                minutos: (secondsBySong[entry.key] ?? 0) ~/ 60,
              ),
            )
            .toList()
          ..sort((a, b) {
            final cmp = b.reproducciones.compareTo(a.reproducciones);
            return cmp != 0 ? cmp : a.songId.compareTo(b.songId);
          });

    final diasOrdenados =
        playsByDay.entries
            .map(
              (entry) => DiaMetrica(
                fecha: entry.key,
                reproducciones: entry.value,
                minutos: (secondsByDay[entry.key] ?? 0) ~/ 60,
              ),
            )
            .toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

    return MetricasArtista(
      totalMinutos: totalSeconds ~/ 60,
      totalReproducciones: records.length,
      rankingOyentes: const [],
      topTemas: topTemas.take(5).toList(),
      reproduccionesPorDia: diasOrdenados.take(7).toList(),
      esSimulacion: true,
    );
  }

  /// Agrega eventos reales de `play_events` por `user_id` dentro del Isolate.
  static List<OyenteTop> aggregateListenersFromPlayEvents(
    List<Map<String, dynamic>> playEvents,
  ) {
    if (playEvents.isEmpty) return const [];

    final secondsByUser = <String, int>{};
    final nameByUser = <String, String>{};
    final cityByUser = <String, String>{};

    for (final event in playEvents) {
      final rawUserId = event['user_id'] as String?;
      final profile = event['profiles'];
      final profileName = profile is Map
          ? (profile['display_name'] as String?)
          : null;
      final explicitName = (event['display_name'] as String?) ?? profileName;

      if ((rawUserId == null || rawUserId.isEmpty) &&
          (explicitName == null || explicitName.trim().isEmpty)) {
        continue;
      }

      final key = (rawUserId != null && rawUserId.isNotEmpty)
          ? rawUserId
          : 'anon_${explicitName!.trim()}';
      final seconds = (event['seconds_listened'] as num?)?.toInt() ?? 0;
      if (seconds <= 0) continue;

      secondsByUser[key] = (secondsByUser[key] ?? 0) + seconds;
      if (explicitName != null && explicitName.trim().isNotEmpty) {
        nameByUser[key] = explicitName.trim();
      } else if (!nameByUser.containsKey(key) && rawUserId != null) {
        final suffix = rawUserId.length > 6
            ? rawUserId.substring(0, 6)
            : rawUserId;
        nameByUser[key] = 'Oyente $suffix';
      }

      final city = (event['city'] as String?)?.trim() ?? '';
      if (city.isNotEmpty && !cityByUser.containsKey(key)) {
        cityByUser[key] = city;
      }
    }

    final ranking =
        secondsByUser.entries
            .map(
              (entry) => OyenteTop(
                nombre: nameByUser[entry.key] ?? 'Oyente',
                minutos: (entry.value / 60).round().clamp(1, 1000000),
                ubicacion: cityByUser[entry.key] ?? '',
              ),
            )
            .toList()
          ..sort((a, b) {
            final cmp = b.minutos.compareTo(a.minutos);
            return cmp != 0 ? cmp : a.nombre.compareTo(b.nombre);
          });

    return ranking.take(5).toList();
  }

  static String _formatDateKey(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day';
  }
}
