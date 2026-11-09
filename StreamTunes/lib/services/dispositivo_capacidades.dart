import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Servicio que encapsula las capacidades del dispositivo y políticas de plataforma.
/// La UI nunca debe acceder a kIsWeb o Platform directamente; debe consultar este servicio.
class DispositivoCapacidades {
  final ImagePicker _picker;
  final bool? forzarTieneCamara;

  DispositivoCapacidades({ImagePicker? picker, this.forzarTieneCamara})
    : _picker = picker ?? ImagePicker();

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
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1200,
      );
      return file?.name ?? file?.path;
    } catch (e) {
      debugPrint('Error al capturar con cámara: $e');
      return null;
    }
  }

  /// Abre la galería de imágenes del dispositivo.
  Future<String?> seleccionarFotoDeGaleria() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      return file?.name ?? file?.path;
    } catch (e) {
      debugPrint('Error al seleccionar de galería: $e');
      return null;
    }
  }
}
