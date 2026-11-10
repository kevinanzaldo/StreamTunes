import 'dart:typed_data';

import '../interfaces/storage_repository.dart';

/// Implementación en memoria de [StorageRepository] para pruebas y modo demo.
class FakeStorageRepository implements StorageRepository {
  final Map<String, Uint8List> uploadedAudio = {};
  final Map<String, Uint8List> uploadedCovers = {};

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
    uploadedAudio[path] = bytes;
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
    uploadedCovers[path] = bytes;
    return path;
  }

  @override
  String getAudioPublicUrl(String path) {
    return 'https://fake-storage.streamtunes.test/audio/$path';
  }

  @override
  String getCoverPublicUrl(String path) {
    return 'https://fake-storage.streamtunes.test/covers/$path';
  }
}
