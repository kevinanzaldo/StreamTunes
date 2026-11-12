import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/playlist.dart';
import '../../models/song.dart';
import '../interfaces/playlist_repository.dart';
import 'song_row_mapper.dart';

/// Implementación real sobre `playlists` y `playlist_songs`.
///
/// Todo es del usuario con sesión iniciada (RLS: `user_id = auth.uid()`).
/// Requiere sesión iniciada del usuario (RLS: `user_id = auth.uid()`). Sin sesión, leer devuelve vacío y escribir lanza error.
class SupabasePlaylistRepository implements PlaylistRepository {
  SupabasePlaylistRepository(this._client);

  final SupabaseClient _client;

  // Sin `!inner`: si RLS esconde un tema (oculto o banda no aprobada), llega
  // `songs: null` y se omite, sin borrar la playlist entera.
  static const String _select =
      '*, playlist_songs(added_at, songs(*, bands(name), albums(title)))';

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Necesitás iniciar sesión para usar tus playlists.');
    }
    return id;
  }

  @override
  Future<List<Playlist>> getMyPlaylists() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('playlists')
        .select(_select)
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Playlist> createPlaylist({
    required String name,
    String description = '',
  }) async {
    final row = await _client
        .from('playlists')
        .insert({
          'user_id': _requireUserId(),
          'name': name,
          'description': description.isEmpty ? null : description,
        })
        .select()
        .single();
    return Playlist.fromJson(row);
  }

  @override
  Future<void> addSong(String playlistId, Song song) async {
    try {
      await _client.from('playlist_songs').insert({
        'playlist_id': playlistId,
        'song_id': song.id,
      });
    } on PostgrestException catch (e) {
      // 23505 = clave duplicada: el tema ya estaba en la playlist.
      if (e.code == '23505') return;
      rethrow;
    }
  }

  @override
  Future<Playlist> updatePlaylist(
    String playlistId, {
    required String name,
    String? description,
  }) async {
    _requireUserId();
    final data = <String, dynamic>{'name': name};
    if (description != null) {
      data['description'] = description.isEmpty ? null : description;
    }
    final row = await _client
        .from('playlists')
        .update(data)
        .eq('id', playlistId)
        .select(_select)
        .single();
    return _fromRow(row);
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    _requireUserId();
    await _client.from('playlists').delete().eq('id', playlistId);
  }

  @override
  Future<void> removeSong(String playlistId, String songId) async {
    await _client
        .from('playlist_songs')
        .delete()
        .eq('playlist_id', playlistId)
        .eq('song_id', songId);
  }

  Playlist _fromRow(Map<String, dynamic> row) {
    final links =
        (row['playlist_songs'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) =>
                (a['added_at'] as String).compareTo(b['added_at'] as String),
          );
    final songs = <Song>[
      for (final link in links)
        if (link['songs'] is Map<String, dynamic>)
          songFromRow(_client, link['songs'] as Map<String, dynamic>),
    ];
    return Playlist.fromJson(row, songs: songs);
  }
}
