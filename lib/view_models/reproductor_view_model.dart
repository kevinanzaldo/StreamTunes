import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import '../repositories/interfaces/song_repository.dart';
import '../services/audio_service.dart';
import '../services/lrc_parser.dart';

class ReproductorViewModel extends ChangeNotifier {
  Song? _cancionActual;
  bool _reproduciendo = false;
  Duration _posicionActual = Duration.zero;
  Duration _duracionTotal = Duration.zero;
  List<Song> _cola = [];
  int _indiceActual = -1;
  bool _aleatorio = false;
  bool _repetir = false;
  List<LrcLine> _lyricsLines = const [];

  Timer? _playbackTimer;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  final AudioService? _audioService;
  final SongRepository? _songRepository;
  int _secondsListenedCurrentSong = 0;

  ReproductorViewModel({this._audioService, this._songRepository}) {
    _audioService?.initSession();
    _initAudioListeners();
  }

  void _initAudioListeners() {
    if (_audioService == null) return;
    _durationSub = _audioService.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        _duracionTotal = dur;
        notifyListeners();
      }
    });

    _positionSub = _audioService.positionStream.listen((pos) {
      if (_reproduciendo) {
        _posicionActual = pos;
        notifyListeners();
      }
    });

    _playerStateSub = _audioService.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_repetir) {
          seekTo(Duration.zero);
          resume();
        } else if (_cola.length > 1) {
          next();
        } else {
          pause();
          _posicionActual = _duracionTotal;
          notifyListeners();
        }
      }
    });
  }

  Song? get currentSong => _cancionActual;
  bool get isPlaying => _reproduciendo;
  Duration get currentPosition => _posicionActual;
  Duration get totalDuration => _duracionTotal;
  bool get isShuffle => _aleatorio;
  bool get isRepeat => _repetir;

  List<LrcLine> get lyricsLines => List.unmodifiable(_lyricsLines);
  bool get hasLyrics => _lyricsLines.isNotEmpty;
  int get activeLyricIndex =>
      LrcParser.activeLineIndex(_lyricsLines, _posicionActual);

  String get songTitle =>
      _cancionActual?.title ?? 'Ninguna canción seleccionada';
  String get artistName =>
      _cancionActual?.artistName ?? 'Elegí una banda independiente';

  double get progress {
    if (_duracionTotal.inMilliseconds == 0) return 0.0;
    return (_posicionActual.inMilliseconds / _duracionTotal.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String get formattedCurrentPosition {
    final minutes = _posicionActual.inMinutes;
    final seconds = _posicionActual.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedTotalDuration {
    final minutes = _duracionTotal.inMinutes;
    final seconds = _duracionTotal.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void play(Song cancion, {List<Song>? cola}) {
    _flushPlayEvent();
    _cancionActual = cancion;
    _lyricsLines = LrcParser.parse(cancion.lyricsLrc);

    if (cola != null && cola.isNotEmpty) {
      _cola = List<Song>.from(cola);
      _indiceActual = _cola.indexOf(cancion);
      if (_indiceActual == -1) {
        _cola.add(cancion);
        _indiceActual = _cola.length - 1;
      }
    } else {
      if (!_cola.contains(cancion)) {
        _cola = [cancion];
        _indiceActual = 0;
      } else {
        _indiceActual = _cola.indexOf(cancion);
      }
    }

    _duracionTotal = cancion.duration;
    _posicionActual = Duration.zero;
    _reproduciendo = true;
    _secondsListenedCurrentSong = 0;

    if (cancion.audioUrl != null && cancion.audioUrl!.isNotEmpty) {
      _audioService?.playUrl(
        cancion.audioUrl!,
        songId: cancion.id,
        title: cancion.title,
        artist: cancion.artistName,
        album: cancion.album,
        coverUrl: cancion.coverUrl,
      );
    } else {
      _audioService?.stop();
    }

    _precargarSiguienteEnCola();
    _startTimer();
    notifyListeners();
  }

  void _precargarSiguienteEnCola() {
    if (_cola.length <= 1 || _indiceActual < 0) return;
    final nextIndex = (_indiceActual + 1) % _cola.length;
    final nextSong = _cola[nextIndex];
    if (nextSong.audioUrl != null && nextSong.audioUrl!.isNotEmpty) {
      unawaited(_audioService?.precargarSiguiente(nextSong.audioUrl));
    }
  }

  void pause() {
    if (_reproduciendo) {
      _reproduciendo = false;
      _stopTimer();
      _audioService?.pause();
      notifyListeners();
    }
  }

  void resume() {
    if (!_reproduciendo && _cancionActual != null) {
      _reproduciendo = true;
      _audioService?.resume();
      _startTimer();
      notifyListeners();
    }
  }

  void togglePlay() {
    if (_cancionActual == null) return;
    _reproduciendo = !_reproduciendo;
    if (_reproduciendo) {
      _audioService?.resume();
      _startTimer();
    } else {
      _audioService?.pause();
      _stopTimer();
    }
    notifyListeners();
  }

  void seekTo(Duration position) {
    if (_cancionActual == null) return;
    _posicionActual = position;
    if (_posicionActual > _duracionTotal) {
      _posicionActual = _duracionTotal;
    } else if (_posicionActual < Duration.zero) {
      _posicionActual = Duration.zero;
    }
    _audioService?.seek(_posicionActual);
    notifyListeners();
  }

  void next() {
    if (_cola.isEmpty || _cancionActual == null) return;

    if (_aleatorio && _cola.length > 1) {
      final rand = Random();
      int newIndex;
      do {
        newIndex = rand.nextInt(_cola.length);
      } while (newIndex == _indiceActual && _cola.length > 1);
      _indiceActual = newIndex;
    } else {
      _indiceActual = (_indiceActual + 1) % _cola.length;
    }

    play(_cola[_indiceActual], cola: _cola);
  }

  void previous() {
    if (_cola.isEmpty || _cancionActual == null) return;

    if (_posicionActual.inSeconds > 3) {
      seekTo(Duration.zero);
      return;
    }

    _indiceActual = (_indiceActual - 1 + _cola.length) % _cola.length;
    play(_cola[_indiceActual], cola: _cola);
  }

  void toggleShuffle() {
    _aleatorio = !_aleatorio;
    notifyListeners();
  }

  void toggleRepeat() {
    _repetir = !_repetir;
    notifyListeners();
  }

  void _startTimer() {
    _stopTimer();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_reproduciendo) {
        timer.cancel();
        return;
      }

      _secondsListenedCurrentSong++;

      final hasRealAudio =
          _audioService != null &&
          _cancionActual?.audioUrl != null &&
          _cancionActual!.audioUrl!.isNotEmpty;

      if (!hasRealAudio) {
        if (_posicionActual + const Duration(seconds: 1) >= _duracionTotal) {
          if (_repetir) {
            _posicionActual = Duration.zero;
            notifyListeners();
          } else {
            next();
          }
        } else {
          _posicionActual += const Duration(seconds: 1);
          notifyListeners();
        }
      }
    });
  }

  void _flushPlayEvent() {
    if (_cancionActual != null && _secondsListenedCurrentSong >= 5) {
      _songRepository?.recordPlayEvent(
        songId: _cancionActual!.id,
        bandId: _cancionActual!.artistId,
        secondsListened: _secondsListenedCurrentSong,
      );
    }
    _secondsListenedCurrentSong = 0;
  }

  void _stopTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  @override
  void dispose() {
    _flushPlayEvent();
    _stopTimer();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _audioService?.dispose();
    super.dispose();
  }
}
