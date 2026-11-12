import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/storage_repository.dart';

/// Implementación real sobre Supabase Storage (buckets `audio` y `covers`).
class SupabaseStorageRepository implements StorageRepository {
  SupabaseStorageRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isMock => false;

  @override
  Future<String> uploadAudio({
    required String bandId,
    required String songId,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.15);
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'mp3';
    final contentType = switch (ext) {
      'wav' => 'audio/wav',
      'm4a' => 'audio/mp4',
      _ => 'audio/mpeg',
    };
    final path = '$bandId/$songId.$ext';
    await _client.storage
        .from('audio')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    onProgress?.call(1.0);
    return path;
  }

  @override
  Future<String> uploadCover({
    required String bandId,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.2);
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path = '$bandId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from('covers')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    onProgress?.call(1.0);
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
