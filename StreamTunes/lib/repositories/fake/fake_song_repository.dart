import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../interfaces/song_repository.dart';

/// Implementación en memoria para tests y modo demo.
class FakeSongRepository implements SongRepository {
  FakeSongRepository({List<Song>? initialSongs}) {
    if (initialSongs != null) {
      _songs.addAll(initialSongs);
    } else {
      _songs.addAll(_defaultSongs);
    }
  }

  static final List<Song> _defaultSongs = [
    Song(
      id: 'song_1',
      title: 'El rito visual',
      artistId: 'artist_1',
      artistName: 'Los Subterráneos',
      album: 'Frecuencias Ocultas',
      duration: const Duration(minutes: 3, seconds: 42),
      genre: 'Indie Rock',
      icon: Icons.music_note,
      gradientColors: const [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      coverUrl:
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
      playCount: 14200,
      uploadedAt: DateTime(2026, 1, 15),
    ),
    Song(
      id: 'song_2',
      title: 'Cables Sueltos',
      artistId: 'artist_2',
      artistName: 'Banda Fractal',
      album: 'Circuito Primario',
      duration: const Duration(minutes: 4, seconds: 15),
      genre: 'Synthwave',
      icon: Icons.album,
      gradientColors: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      coverUrl:
          'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
      playCount: 9800,
      uploadedAt: DateTime(2026, 1, 14),
    ),
    Song(
      id: 'song_3',
      title: 'Ruido Blanco',
      artistId: 'artist_3',
      artistName: 'Terapia de Choque',
      album: 'Bajo Control',
      duration: const Duration(minutes: 2, seconds: 58),
      genre: 'Post-Punk',
      icon: Icons.headphones,
      gradientColors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      coverUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
      playCount: 7400,
      uploadedAt: DateTime(2026, 1, 2),
    ),
    Song(
      id: 'song_4',
      title: 'Ecos del Sur',
      artistId: 'artist_4',
      artistName: 'Vientos Nómadas',
      album: 'Camino Abierto',
      duration: const Duration(minutes: 3, seconds: 20),
      genre: 'Folk Acústico',
      icon: Icons.mic,
      gradientColors: const [Color(0xFFF7971E), Color(0xFFFFD200)],
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      coverUrl:
          'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=300',
      playCount: 18300,
      uploadedAt: DateTime(2025, 12, 25),
    ),
  ];

  final List<Song> _songs = [];
  final List<Map<String, dynamic>> recordedPlayEvents = [];

  @override
  Future<List<Song>> getLatestSongs({int limit = 50}) async {
    final sorted = List<Song>.of(_songs)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return List.unmodifiable(sorted.take(limit));
  }

  @override
  Future<List<Song>> getSongsByBand(String bandId) async {
    return List.unmodifiable(_songs.where((s) => s.artistId == bandId));
  }

  @override
  Future<Song> addSong(Song song, {String? albumId}) async {
    _songs.insert(0, song);
    return song;
  }

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
