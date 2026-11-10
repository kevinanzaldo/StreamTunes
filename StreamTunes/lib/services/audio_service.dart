import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Servicio de audio real que encapsula [AudioPlayer] de `just_audio`
/// y maneja interrupciones de llamadas telefónicas con `audio_session` (Criterio E3).
class AudioService {
  AudioPlayer? _player;
  AudioSession? _session;
  StreamSubscription? _interruptionSubscription;

  /// Política de reproducción: si se reanuda automáticamente tras una llamada o no.
  final bool reanudarTrasLlamada;

  final VoidCallback? onInterruptionPause;
  final VoidCallback? onInterruptionResume;

  AudioService({
    this.reanudarTrasLlamada = true,
    this.onInterruptionPause,
    this.onInterruptionResume,
    AudioPlayer? player,
  }) {
    _player = player;
  }

  AudioPlayer get player => _player ??= AudioPlayer();

  /// Inicializa la sesión de audio y escucha eventos de interrupción (llamadas, alarmas).
  Future<void> initSession() async {
    try {
      _session = await AudioSession.instance;
      await _session?.configure(const AudioSessionConfiguration.music());

      _interruptionSubscription = _session?.interruptionEventStream.listen((
        event,
      ) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              onInterruptionPause?.call();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
            case AudioInterruptionType.pause:
              if (reanudarTrasLlamada) {
                onInterruptionResume?.call();
              }
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('AudioSession no disponible en esta plataforma/entorno: $e');
    }
  }

  /// Carga y reproduce una URL de audio pública.
  Future<void> playUrl(String url) async {
    try {
      await player.setUrl(url);
      await player.play();
    } catch (e) {
      debugPrint('AudioService: reproducción simulada o error en URL: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player?.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await _player?.play();
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  Future<void> seek(Duration position) async {
    try {
      await _player?.seek(position);
    } catch (_) {}
  }

  void dispose() {
    _interruptionSubscription?.cancel();
    _player?.dispose();
  }
}
