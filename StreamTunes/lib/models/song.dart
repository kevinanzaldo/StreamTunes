import 'package:flutter/material.dart';

class Song {
  final String id;
  final String title;
  final String artistId;
  final String artistName;
  final String album;
  final Duration duration;
  final String genre;
  final IconData icon;
  final List<Color> gradientColors;
  final String? audioUrl;
  final int playCount;
  final DateTime uploadedAt;

  const Song({
    required this.id,
    required this.title,
    required this.artistId,
    required this.artistName,
    required this.album,
    required this.duration,
    required this.genre,
    required this.icon,
    required this.gradientColors,
    this.audioUrl,
    this.playCount = 0,
    required this.uploadedAt,
  });

  /// Construye un tema desde una fila de la tabla `songs`.
  ///
  /// `audio_path` es una ruta de Storage (`{band_id}/{song_id}.mp3`), no una URL:
  /// el servicio de Storage la convierte a URL pública antes de reproducir.
  /// El ícono y el degradado son solo de presentación (la base no los guarda).
  factory Song.fromJson(
    Map<String, dynamic> json, {
    String artistName = '',
    String album = '',
  }) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      artistId: json['band_id'] as String,
      artistName: artistName,
      album: album,
      duration: Duration(seconds: (json['duration_s'] as num).toInt()),
      genre: (json['genre'] as String?) ?? '',
      icon: Icons.music_note,
      gradientColors: const [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
      audioUrl: json['audio_path'] as String?,
      playCount: (json['play_count'] as num?)?.toInt() ?? 0,
      uploadedAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Campos permitidos al insertar en `songs` (ver privilegios por columna).
  Map<String, dynamic> toInsertJson({String? albumId}) => {
    'band_id': artistId,
    'album_id': albumId,
    'title': title,
    'genre': genre,
    'audio_path': audioUrl ?? '',
    'duration_s': duration.inSeconds,
  };

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
