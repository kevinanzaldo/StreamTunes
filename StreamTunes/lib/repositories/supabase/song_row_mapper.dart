import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/song.dart';

/// Arma un [Song] desde una fila de `songs`, con `bands(name)` y `albums(title)`
/// embebidos, y convierte `audio_path` (ruta de Storage) en URL pública del
/// bucket `audio`. Lo comparten los repositorios de temas y de playlists.
Song songFromRow(SupabaseClient client, Map<String, dynamic> row) {
  final band = row['bands'] as Map<String, dynamic>?;
  final album = row['albums'] as Map<String, dynamic>?;
  final path = row['audio_path'] as String?;
  final resolved = <String, dynamic>{
    ...row,
    'audio_path': (path == null || path.isEmpty)
        ? path
        : client.storage.from('audio').getPublicUrl(path),
  };
  return Song.fromJson(
    resolved,
    artistName: (band?['name'] as String?) ?? '',
    album: (album?['title'] as String?) ?? '',
  );
}
