class PlaybackRecord {
  final String id;
  final String songId;
  final String artistId;
  final int durationSeconds;
  final DateTime timestamp;

  const PlaybackRecord({
    required this.id,
    required this.songId,
    required this.artistId,
    required this.durationSeconds,
    required this.timestamp,
  });
}
