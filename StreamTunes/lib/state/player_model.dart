import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/song.dart';

class PlayerModel extends ChangeNotifier {
  Song? _currentSong;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isShuffle = false;
  bool _isRepeat = false;

  Timer? _playbackTimer;

  // Getters
  Song? get currentSong => _currentSong;
  bool get hasSong => _currentSong != null;
  String get songTitle => _currentSong?.title ?? 'Ninguna canción seleccionada';
  String get artistName =>
      _currentSong?.artistName ?? 'Selecciona un artista independiente';
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  List<Song> get queue => _queue;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;

  double get progress {
    if (_totalDuration.inMilliseconds == 0) return 0.0;
    return (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String get formattedCurrentPosition {
    final minutes = _currentPosition.inMinutes;
    final seconds = _currentPosition.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedTotalDuration {
    final minutes = _totalDuration.inMinutes;
    final seconds = _totalDuration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void playSong(Song song, {List<Song>? queue}) {
    _currentSong = song;
    if (queue != null && queue.isNotEmpty) {
      _queue = List.from(queue);
      _currentIndex = _queue.indexOf(song);
      if (_currentIndex == -1) {
        _queue.add(song);
        _currentIndex = _queue.length - 1;
      }
    } else {
      if (!_queue.contains(song)) {
        _queue = [song];
        _currentIndex = 0;
      } else {
        _currentIndex = _queue.indexOf(song);
      }
    }

    _totalDuration = song.duration;
    _currentPosition = Duration.zero;
    _isPlaying = true;

    _startTimer();
    notifyListeners();
  }

  void togglePlay() {
    if (_currentSong == null) return;
    _isPlaying = !_isPlaying;
    if (_isPlaying) {
      _startTimer();
    } else {
      _stopTimer();
    }
    notifyListeners();
  }

  void pause() {
    if (_isPlaying) {
      _isPlaying = false;
      _stopTimer();
      notifyListeners();
    }
  }

  void resume() {
    if (!_isPlaying && _currentSong != null) {
      _isPlaying = true;
      _startTimer();
      notifyListeners();
    }
  }

  void seekTo(Duration position) {
    if (_currentSong == null) return;
    _currentPosition = position;
    if (_currentPosition > _totalDuration) {
      _currentPosition = _totalDuration;
    } else if (_currentPosition < Duration.zero) {
      _currentPosition = Duration.zero;
    }
    notifyListeners();
  }

  void next() {
    if (_queue.isEmpty || _currentSong == null) return;

    if (_isShuffle && _queue.length > 1) {
      final rand = Random();
      int newIndex;
      do {
        newIndex = rand.nextInt(_queue.length);
      } while (newIndex == _currentIndex && _queue.length > 1);
      _currentIndex = newIndex;
    } else {
      _currentIndex = (_currentIndex + 1) % _queue.length;
    }

    playSong(_queue[_currentIndex], queue: _queue);
  }

  void previous() {
    if (_queue.isEmpty || _currentSong == null) return;

    // Si ya pasaron más de 3 segundos, reiniciar la pista actual
    if (_currentPosition.inSeconds > 3) {
      seekTo(Duration.zero);
      return;
    }

    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    playSong(_queue[_currentIndex], queue: _queue);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    notifyListeners();
  }

  void _startTimer() {
    _stopTimer();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }

      if (_currentPosition + const Duration(seconds: 1) >= _totalDuration) {
        if (_isRepeat) {
          _currentPosition = Duration.zero;
          notifyListeners();
        } else {
          next();
        }
      } else {
        _currentPosition += const Duration(seconds: 1);
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
