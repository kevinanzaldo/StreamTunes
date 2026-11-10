import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/storage_repository.dart';

/// Implementación real sobre Supabase Storage (buckets `audio` y `covers`).
class SupabaseStorageRepository implements StorageRepository {
  SupabaseStorageRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> uploadAudio({
    required String bandId,
    required String songId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'mp3';
    final path = '$bandId/$songId.$ext';
    await _client.storage
        .from('audio')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'audio/mpeg',
            upsert: true,
          ),
        );
    return path;
  }

  @override
  Future<String> uploadCover({
    required String bandId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final path = '$bandId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from('covers')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return path;
  }

  @override
  String getAudioPublicUrl(String path) {
    return _client.storage.from('audio').getPublicUrl(path);
  }

  @override
  String getCoverPublicUrl(String path) {
    return _client.storage.from('covers').getPublicUrl(path);
  }
}
