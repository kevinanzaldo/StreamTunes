import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/song.dart';
import '../interfaces/song_repository.dart';
import 'song_row_mapper.dart';

/// Implementación real sobre la tabla `songs`.
///
/// - Lectura: devuelve `audioUrl` ya convertido a URL pública del bucket `audio`.
/// - Escritura: `Song.audioUrl` debe contener la **ruta de Storage**
///   (`{band_id}/{song_id}.mp3`) del archivo ya subido, no una URL.
/// - Los errores de la base (cupo de 20 temas, RLS) llegan como
///   `PostgrestException`; el view model decide cómo mostrarlos.
class SupabaseSongRepository implements SongRepository {
  SupabaseSongRepository(this._client);

  final SupabaseClient _client;

  static const String _select =
      '*, bands!inner(name, status, cover_url), albums(title, cover_url)';

  @override
  Future<List<Song>> getLatestSongs({int limit = 50}) async {
    final rows = await _client
        .from('songs')
        .select(_select)
        .eq('bands.status', 'approved')
        .eq('hidden', false)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((row) => songFromRow(_client, row)).toList();
  }

  @override
  Future<List<Song>> getSongsByBand(String bandId) async {
    final rows = await _client
        .from('songs')
        .select(_select)
        .eq('band_id', bandId)
        .order('created_at', ascending: false);
    return rows.map((row) => songFromRow(_client, row)).toList();
  }

  bool _isMissingCoverUrlColumn(PostgrestException e) {
    final msg = e.message.toLowerCase();
    return (e.code == '42703' || e.code == 'PGRST204') &&
        msg.contains('cover_url');
  }

  bool _isMissingAlbumsTable(PostgrestException e) {
    final msg = e.message.toLowerCase();
    return (e.code == '42P01' || e.code == 'PGRST205') &&
        msg.contains('albums');
  }

  bool _isMissingLyricsColumn(PostgrestException e) {
    final msg = e.message.toLowerCase();
    return (e.code == '42703' || e.code == 'PGRST204') &&
        msg.contains('lyrics');
  }

  Future<String?> _resolveOrCreateAlbumId(Song song) async {
    final albumTitle = song.album.trim();
    final hasCover = song.coverUrl != null && song.coverUrl!.isNotEmpty;

    Map<String, dynamic>? existing;
    var albumTableHasCoverUrl = true;
    try {
      existing = await _client
          .from('albums')
          .select('id, cover_url')
          .eq('band_id', song.artistId)
          .eq('title', albumTitle)
          .maybeSingle();
    } on PostgrestException catch (e) {
      if (_isMissingAlbumsTable(e)) {
        return null;
      }
      if (!_isMissingCoverUrlColumn(e)) {
        rethrow;
      }
      albumTableHasCoverUrl = false;
      existing = await _client
          .from('albums')
          .select('id')
          .eq('band_id', song.artistId)
          .eq('title', albumTitle)
          .maybeSingle();
    }

    if (existing != null) {
      final resolvedAlbumId = existing['id'] as String?;
      if (resolvedAlbumId != null && hasCover && albumTableHasCoverUrl) {
        try {
          await _client
              .from('albums')
              .update({'cover_url': song.coverUrl})
              .eq('id', resolvedAlbumId);
        } on PostgrestException catch (e) {
          if (!_isMissingCoverUrlColumn(e)) {
            rethrow;
          }
        }
      }
      return resolvedAlbumId;
    }

    try {
      final insertedAlbum = await _client
          .from('albums')
          .insert({
            'band_id': song.artistId,
            'title': albumTitle,
            if (hasCover && albumTableHasCoverUrl) 'cover_url': song.coverUrl,
          })
          .select('id')
          .single();
      return insertedAlbum['id'] as String?;
    } on PostgrestException catch (e) {
      if (_isMissingAlbumsTable(e)) {
        return null;
      }
      if (!_isMissingCoverUrlColumn(e)) {
        rethrow;
      }
      final insertedAlbum = await _client
          .from('albums')
          .insert({'band_id': song.artistId, 'title': albumTitle})
          .select('id')
          .single();
      return insertedAlbum['id'] as String?;
    }
  }

  @override
  Future<Song> addSong(Song song, {String? albumId}) async {
    String? resolvedAlbumId = albumId;

    // Si tiene álbum especificado, vincular o crear en la tabla `albums`.
    // No se silencian errores de negocio (por ejemplo `albums_limit`) ni de RLS.
    if (resolvedAlbumId == null && song.album.trim().isNotEmpty) {
      resolvedAlbumId = await _resolveOrCreateAlbumId(song);
    }

    final insertData = <String, dynamic>{
      ...song.toInsertJson(albumId: resolvedAlbumId),
      if (song.coverUrl != null && song.coverUrl!.isNotEmpty)
        'cover_url': song.coverUrl,
    };

    Map<String, dynamic> row;
    try {
      row = await _client
          .from('songs')
          .insert(insertData)
          .select(_select)
          .single();
    } on PostgrestException catch (e) {
      if (!_isMissingCoverUrlColumn(e) && !_isMissingLyricsColumn(e)) {
        rethrow;
      }
      if (_isMissingLyricsColumn(e)) {
        insertData.remove('lyrics_lrc');
      }
      if (_isMissingCoverUrlColumn(e)) {
        insertData.remove('cover_url');
      }
      row = await _client
          .from('songs')
          .insert(insertData)
          .select(_select)
          .single();
    }
    return songFromRow(_client, row);
  }

  @override
  Future<void> recordPlayEvent({
    required String songId,
    required String bandId,
    required int secondsListened,
    String? userId,
  }) async {
    await _client.from('play_events').insert({
      'song_id': songId,
      'band_id': bandId,
      'seconds_listened': secondsListened,
      'user_id': userId ?? _client.auth.currentUser?.id,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getPlayEventsByBand(String bandId) async {
    final rows = await _client
        .from('play_events')
        .select(
          'song_id, user_id, seconds_listened, created_at, profiles(display_name)',
        )
        .eq('band_id', bandId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}
