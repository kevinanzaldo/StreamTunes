import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/song.dart';

class ReproductorViewModel extends ChangeNotifier {
  Song? _cancionActual;
  bool _reproduciendo = false;
  Duration _posicionActual = Duration.zero;
  Duration _duracionTotal = Duration.zero;
  List<Song> _cola = [];
  int _indiceActual = -1;
  bool _aleatorio = false;
  bool _repetir = false;

  Timer? _playbackTimer;

  // Getters públicos
  Song? get cancionActual => _cancionActual;
  Song? get currentSong => _cancionActual;

  bool get reproduciendo => _reproduciendo;
  bool get isPlaying => _reproduciendo;

  bool get hasSong => _cancionActual != null;

  Duration get posicionActual => _posicionActual;
  Duration get currentPosition => _posicionActual;

  Duration get duracionTotal => _duracionTotal;
  Duration get totalDuration => _duracionTotal;

  List<Song> get cola => List.unmodifiable(_cola);
  List<Song> get queue => _cola;

  bool get aleatorio => _aleatorio;
  bool get isShuffle => _aleatorio;

  bool get repetir => _repetir;
  bool get isRepeat => _repetir;

  String get songTitle =>
      _cancionActual?.title ?? 'Ninguna canción seleccionada';
  String get artistName =>
      _cancionActual?.artistName ?? 'Selecciona un artista independiente';

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

  // Métodos que modifican el estado (llaman notifyListeners internamente)
  void play(Song cancion, {List<Song>? cola}) {
    _cancionActual = cancion;
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

    _startTimer();
    notifyListeners();
  }

  void playSong(Song song, {List<Song>? queue}) {
    play(song, cola: queue);
  }

  void pause() {
    if (_reproduciendo) {
      _reproduciendo = false;
      _stopTimer();
      notifyListeners();
    }
  }

  void resume() {
    if (!_reproduciendo && _cancionActual != null) {
      _reproduciendo = true;
      _startTimer();
      notifyListeners();
    }
  }

  void togglePlay() {
    if (_cancionActual == null) return;
    _reproduciendo = !_reproduciendo;
    if (_reproduciendo) {
      _startTimer();
    } else {
      _stopTimer();
    }
    notifyListeners();
  }

  void cambiarTema(Song nuevaCancion) {
    play(nuevaCancion, cola: _cola);
  }

  void seekTo(Duration position) {
    if (_cancionActual == null) return;
    _posicionActual = position;
    if (_posicionActual > _duracionTotal) {
      _posicionActual = _duracionTotal;
    } else if (_posicionActual < Duration.zero) {
      _posicionActual = Duration.zero;
    }
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
    });
  }

  void _stopTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
