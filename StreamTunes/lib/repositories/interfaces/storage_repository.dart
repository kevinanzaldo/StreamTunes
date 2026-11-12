import 'dart:typed_data';

/// Interfaz para operaciones con el almacenamiento de archivos (Supabase Storage).
abstract class StorageRepository {
  /// Sube un archivo de audio al bucket `audio` en la ruta `{bandId}/{songId}.{ext}`.
  /// Devuelve la ruta relativa dentro del bucket (por ejemplo, `band_1/song_123.mp3`).
  Future<String> uploadAudio({
    required String bandId,
    required String songId,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  });

  /// Sube una imagen de portada al bucket `covers`.
  /// Devuelve la ruta relativa dentro del bucket.
  Future<String> uploadCover({
    required String bandId,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  });

  /// Obtiene la URL pública de lectura directa de un archivo de audio.
  String getAudioPublicUrl(String path);

  /// Obtiene la URL pública de una portada.
  String getCoverPublicUrl(String path);

  /// Indica si es una implementación de prueba/mock.
  bool get isMock => false;
}
