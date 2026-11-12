import 'dart:convert';
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
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.35);
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'mp3';
    final path = '$bandId/$songId.$ext';
    uploadedAudio[path] = bytes;
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
    onProgress?.call(0.5);
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final path = '$bandId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    uploadedCovers[path] = bytes;
    onProgress?.call(1.0);
    return path;
  }

  @override
  String getAudioPublicUrl(String path) {
    return 'https://fake-storage.streamtunes.test/audio/$path';
  }

  /// En modo demo las portadas subidas se devuelven como `data:` URI para que
  /// se vean sin servidor; las rutas que no se subieron acá apuntan a un host
  /// de prueba.
  @override
  String getCoverPublicUrl(String path) {
    final bytes = uploadedCovers[path];
    if (bytes == null) {
      return 'https://fake-storage.streamtunes.test/covers/$path';
    }
    final mime = path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  @override
  bool get isMock => true;
}
