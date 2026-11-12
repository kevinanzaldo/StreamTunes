import 'package:flutter/material.dart';

import '../../models/playlist.dart';
import '../../models/song.dart';
import '../interfaces/playlist_repository.dart';

/// Implementación en memoria (tests y modo demo). Devuelve copias,
/// de modo que mutar lo devuelto no altera la base simulada.
class FakePlaylistRepository implements PlaylistRepository {
  FakePlaylistRepository({List<Playlist>? initialPlaylists})
    : _playlists = initialPlaylists ?? _defaultPlaylists();

  final List<Playlist> _playlists;

  static List<Playlist> _defaultPlaylists() => [
    Playlist(
      id: 'pl_1',
      name: 'Favoritos Under',
      description: 'Joyas ocultas del circuito independiente',
      coverGradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      icon: Icons.favorite,
    ),
    Playlist(
      id: 'pl_2',
      name: 'Noche de Garaje',
      description: 'Sonido crudo para altas horas',
      coverGradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      icon: Icons.nightlife,
    ),
  ];

  Playlist _copy(Playlist p) => Playlist(
    id: p.id,
    name: p.name,
    description: p.description,
    songs: List<Song>.of(p.songs),
    createdAt: p.createdAt,
    coverGradient: p.coverGradient,
    icon: p.icon,
  );

  Playlist _byId(String id) => _playlists.firstWhere(
    (p) => p.id == id,
    orElse: () => throw StateError('La playlist $id no existe.'),
  );

  @override
  Future<List<Playlist>> getMyPlaylists() async =>
      _playlists.map(_copy).toList();

  @override
  Future<Playlist> createPlaylist({
    required String name,
    String description = '',
  }) async {
    final playlist = Playlist(
      id: 'pl_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      description: description,
      coverGradient: [
        const Color(0xFF1DB954),
        Colors.primaries[(_playlists.length + 3) % Colors.primaries.length],
      ],
      icon: Icons.music_note,
    );
    _playlists.insert(0, playlist);
    return _copy(playlist);
  }

  @override
  Future<void> addSong(String playlistId, Song song) async {
    final playlist = _byId(playlistId);
    if (!playlist.songs.any((s) => s.id == song.id)) {
      playlist.songs.add(song);
    }
  }

  @override
  Future<void> removeSong(String playlistId, String songId) async {
    _byId(playlistId).songs.removeWhere((s) => s.id == songId);
  }
}
