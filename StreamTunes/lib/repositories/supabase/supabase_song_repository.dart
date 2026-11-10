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

  static const String _select = '*, bands!inner(name, status), albums(title)';

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

  @override
  Future<Song> addSong(Song song, {String? albumId}) async {
    final row = await _client
        .from('songs')
        .insert(song.toInsertJson(albumId: albumId))
        .select(_select)
        .single();
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
}
