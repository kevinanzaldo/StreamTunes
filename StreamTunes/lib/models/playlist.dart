import 'package:flutter/material.dart';
import 'song.dart';

class Playlist {
  final String id;
  String name;
  String description;
  final List<Song> songs;
  final DateTime createdAt;
  final List<Color> coverGradient;
  final IconData icon;

  Playlist({
    required this.id,
    required this.name,
    this.description = '',
    List<Song>? songs,
    DateTime? createdAt,
    this.coverGradient = const [Color(0xFF450af5), Color(0xFFc4efd9)],
    this.icon = Icons.queue_music,
  })  : songs = songs ?? [],
        createdAt = createdAt ?? DateTime.now();

  int get songCount => songs.length;

  Duration get totalDuration {
    return songs.fold(Duration.zero, (total, song) => total + song.duration);
  }

  String get formattedTotalDuration {
    final totalMinutes = totalDuration.inMinutes;
    if (totalMinutes > 60) {
      final hours = totalMinutes ~/ 60;
      final remainingMins = totalMinutes % 60;
      return '${hours}h ${remainingMins}m';
    }
    return '$totalMinutes mins';
  }
}
