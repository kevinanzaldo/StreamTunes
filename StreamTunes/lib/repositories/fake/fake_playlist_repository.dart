import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../interfaces/playlist_repository.dart';

/// Implementación en memoria (tests y modo demo). Parte de las playlists de
/// `MockData` y devuelve copias, así que mutar lo devuelto no cambia lo guardado.
class FakePlaylistRepository implements PlaylistRepository {
  FakePlaylistRepository() : _playlists = MockData.getInitialPlaylists();

  final List<Playlist> _playlists;

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
