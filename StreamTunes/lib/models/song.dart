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
