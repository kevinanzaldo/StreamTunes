import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Representa un archivo de imagen seleccionado para portada de tema o banda.
class SelectedImageFile {
  final String name;
  final Uint8List bytes;
  final String? path;

  const SelectedImageFile({
    required this.name,
    required this.bytes,
    this.path,
  });
}

/// Representa un archivo de audio seleccionado por el usuario para su subida.
class SelectedAudioFile {
  final String name;
  final int size;
  final Uint8List? bytes;
  final String? path;

  const SelectedAudioFile({
    required this.name,
    required this.size,
    this.bytes,
    this.path,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Servicio que encapsula las capacidades del dispositivo y políticas de plataforma.
/// La UI nunca debe acceder a kIsWeb o Platform directamente; debe consultar este servicio.
class DispositivoCapacidades {
  final ImagePicker _picker;
  final bool? forzarTieneCamara;
  final Future<SelectedAudioFile?> Function()? audioPickerOverride;

  DispositivoCapacidades({
    ImagePicker? picker,
    this.forzarTieneCamara,
    this.audioPickerOverride,
  }) : _picker = picker ?? ImagePicker();

  /// Getter asincrónico que determina si el dispositivo cuenta con cámara utilizable.
  Future<bool> get tieneCamara async {
    if (forzarTieneCamara != null) {
      return forzarTieneCamara!;
    }

    // En web tradicional de escritorio o entornos sin cámara nativa directa, se oculta.
    // En móviles (Android / iOS) la cámara está disponible.
    if (kIsWeb) {
      // En Web PWA, podemos evaluar soporte o deshabilitar captura directa si no hay cámara
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  /// Abre la cámara del dispositivo para capturar una imagen o foto de portada.
  Future<String?> tomarFotoConCamara() async {
    final img = await tomarFotoArchivo();
    return img?.name ?? img?.path;
  }

  /// Captura foto con cámara devolviendo nombre y bytes reales para subida.
  Future<SelectedImageFile?> tomarFotoArchivo() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return SelectedImageFile(
        name: file.name,
        bytes: bytes,
        path: file.path,
      );
    } catch (e) {
      debugPrint('Error al capturar con cámara: $e');
      return null;
    }
  }

  /// Abre la galería de imágenes del dispositivo.
  Future<String?> seleccionarFotoDeGaleria() async {
    final img = await seleccionarFotoArchivo();
    return img?.name ?? img?.path;
  }

  /// Selecciona imagen de galería con bytes reales para subida.
  Future<SelectedImageFile?> seleccionarFotoArchivo() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return SelectedImageFile(
        name: file.name,
        bytes: bytes,
        path: file.path,
      );
    } catch (e) {
      debugPrint('Error al seleccionar de galería: $e');
      return null;
    }
  }

  /// Permite a las bandas grabar historias o videos cortos (15 segundos) desde recitales o ensayos (Bloque 1).
  Future<String?> grabarHistoriaCorta() async {
    try {
      final XFile? file = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 15),
      );
      return file?.name ?? file?.path;
    } catch (e) {
      debugPrint('Error al grabar historia con cámara: $e');
      return null;
    }
  }

  /// Selecciona un archivo de audio real (.mp3, .m4a, .wav) con FilePicker.
  Future<SelectedAudioFile?> seleccionarArchivoAudio() async {
    if (audioPickerOverride != null) {
      return audioPickerOverride!();
    }
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav'],
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      final size = (await file.length()) ?? bytes.length;
      return SelectedAudioFile(
        name: file.name,
        size: size,
        bytes: bytes,
        path: file.path,
      );
    } catch (e) {
      debugPrint('Error al seleccionar archivo de audio: $e');
      return null;
    }
  }

  /// Ejecuta cálculos pesados en un hilo secundario sin congelar la UI (Criterios D3, Multiplataforma).
  /// Encapsula Isolate.run en plataformas nativas y compute en Web.
  Future<R> ejecutarComputoPesado<T, R>(
    ComputeCallback<T, R> callback,
    T message,
  ) async {
    if (kIsWeb) {
      return compute(callback, message);
    } else {
      return Isolate.run(() => callback(message));
    }
  }
}
