import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Servicio de audio que encapsula [AudioPlayer] de `just_audio`, reproducción en
/// segundo plano con pantalla bloqueada en Android (`just_audio_background`),
/// precarga de la siguiente pista e interrupciones de llamadas vía `audio_session`.
///
/// Limitación documentada en Web (PWA): los navegadores web no exponen eventos
/// del sistema operativo para llamadas telefónicas entrantes; en Android sí
/// funcionan mediante el foco de audio del sistema (`AudioSessionConfiguration.music()`).
class AudioService {
  static bool _backgroundInitialized = false;

  /// Inicializa el servicio foreground en Android para que la música siga sonando
  /// con la pantalla bloqueada y muestre controles en la notificación multimedia.
  static Future<void> initBackgroundPlayback() async {
    if (_backgroundInitialized || kIsWeb) return;
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.streamtunes.app.channel.audio',
        androidNotificationChannelName: 'Reproducción de StreamTunes',
        androidNotificationOngoing: true,
      );
      _backgroundInitialized = true;
    } catch (e) {
      debugPrint('JustAudioBackground no disponible en este entorno: $e');
    }
  }

  AudioPlayer? _player;
  AudioPlayer? _preloadPlayer;
  AudioSession? _session;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  String? _preloadedUrl;

  /// Política de reproducción: reanuda automáticamente tras finalizar una llamada.
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

  /// Inicializa la sesión de audio y escucha eventos de foco/interrupción
  /// (llamadas telefónicas, alarmas en Android).
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

  /// Streams directos del reproductor subyacente para sincronizar UI y fin de tema.
  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;
  Stream<PlayerState> get playerStateStream => player.playerStateStream;
  Duration get currentPosition => _player?.position ?? Duration.zero;

  /// Carga y reproduce una URL de audio pública, adjuntando metadatos para pantalla
  /// bloqueada en Android cuando `just_audio_background` está activo.
  Future<void> playUrl(
    String url, {
    String? songId,
    String? title,
    String? artist,
    String? album,
    String? coverUrl,
  }) async {
    try {
      await player.stop();
      if (_backgroundInitialized) {
        final artUri = (coverUrl != null && coverUrl.startsWith('http'))
            ? Uri.tryParse(coverUrl)
            : null;
        await player.setAudioSource(
          AudioSource.uri(
            Uri.parse(url),
            tag: MediaItem(
              id: songId ?? url,
              title: title ?? 'StreamTunes',
              artist: artist ?? 'Banda independiente',
              album: album,
              artUri: artUri,
            ),
          ),
        );
      } else {
        await player.setUrl(url);
      }
      await player.play();
    } catch (e) {
      debugPrint('AudioService: error al cargar URL "$url": $e');
      try {
        await player.stop();
      } catch (_) {}
    }
  }

  /// Precarga/pre-bufferea la siguiente canción en segundo plano para tolerar
  /// cortes breves de señal (ej. túneles o sótanos sin recepción continua).
  Future<void> precargarSiguiente(String? url) async {
    if (url == null || url.isEmpty || url == _preloadedUrl) return;
    _preloadedUrl = url;
    try {
      _preloadPlayer ??= AudioPlayer();
      await _preloadPlayer!.setVolume(0);
      await _preloadPlayer!.setUrl(url, preload: true);
    } catch (e) {
      debugPrint('AudioService: precarga opcional omitida ($url): $e');
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
    _preloadPlayer?.dispose();
  }
}
