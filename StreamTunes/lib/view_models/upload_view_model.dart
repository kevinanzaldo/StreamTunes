import 'package:flutter/material.dart';

import '../models/song.dart';
import '../repositories/music_repository.dart';
import '../services/background_upload_service.dart';
import '../services/dispositivo_capacidades.dart';

class UploadViewModel extends ChangeNotifier {
  final DispositivoCapacidades _dispositivoCapacidades;
  final MusicRepository _musicRepository;

  bool _tieneCamara = false;
  bool _cargandoCapacidades = true;
  String? _fotoPortadaPath;
  String? _nombreArchivoAudio;
  bool _subiendo = false;
  String? _mensajeExito;
  String? _error;

  UploadViewModel({
    DispositivoCapacidades? dispositivoCapacidades,
    MusicRepository? musicRepository,
    bool autoInicializar = true,
  }) : _dispositivoCapacidades =
           dispositivoCapacidades ?? DispositivoCapacidades(),
       _musicRepository = musicRepository ?? MusicRepository() {
    if (autoInicializar) {
      inicializarCapacidades();
    }
  }

  bool get tieneCamara => _tieneCamara;
  bool get cargandoCapacidades => _cargandoCapacidades;
  String? get fotoPortadaPath => _fotoPortadaPath;
  String? get nombreArchivoAudio => _nombreArchivoAudio;
  bool get tienePortada => _fotoPortadaPath != null;
  bool get tieneAudio => _nombreArchivoAudio != null;
  bool get subiendo => _subiendo;
  String? get mensajeExito => _mensajeExito;
  String? get error => _error;

  /// Consulta asincrónica de capacidades del dispositivo (Bloque 3 - Criterios D1, F1).
  Future<void> inicializarCapacidades() async {
    _cargandoCapacidades = true;
    notifyListeners();

    _tieneCamara = await _dispositivoCapacidades.tieneCamara;
    _cargandoCapacidades = false;
    notifyListeners();
  }

  Future<void> tomarFotoConCamara() async {
    final result = await _dispositivoCapacidades.tomarFotoConCamara();
    if (result != null) {
      _fotoPortadaPath = result;
      _error = null;
      notifyListeners();
    }
  }

  Future<void> seleccionarFotoDeGaleria() async {
    final result = await _dispositivoCapacidades.seleccionarFotoDeGaleria();
    if (result != null) {
      _fotoPortadaPath = result;
      _error = null;
      notifyListeners();
    }
  }

  void seleccionarArchivoAudio(String fileName) {
    _nombreArchivoAudio = fileName;
    _error = null;
    notifyListeners();
  }

  Future<bool> publicarTema({
    required String titulo,
    String album = 'Demo',
    String artistId = 'artist_1',
    String artistName = 'Los Subterráneos',
    bool subirEnSegundoPlano = true,
  }) async {
    if (titulo.trim().isEmpty) {
      _error = 'Ingresa el título del tema';
      notifyListeners();
      return false;
    }

    // Validación de límites del MVP: máximo 20 temas o 2 álbumes por banda (Criterio A1)
    final existingSongs = _musicRepository.getSongsByArtist(artistId);
    if (existingSongs.length >= 20) {
      _error = 'Límite de subida alcanzado: máximo 20 temas por banda.';
      notifyListeners();
      return false;
    }

    final existingAlbums = existingSongs
        .map((s) => s.album.trim().toLowerCase())
        .where((alb) => alb.isNotEmpty)
        .toSet();

    final targetAlbum = album.trim().toLowerCase();
    if (!existingAlbums.contains(targetAlbum) && existingAlbums.length >= 2) {
      _error = 'Límite de subida alcanzado: máximo 2 álbumes por banda.';
      notifyListeners();
      return false;
    }

    _subiendo = true;
    _error = null;
    notifyListeners();

    try {
      final nuevaCancion = Song(
        id: 'song_${DateTime.now().millisecondsSinceEpoch}',
        title: titulo.trim(),
        artistId: artistId,
        artistName: artistName,
        album: album.trim(),
        duration: const Duration(minutes: 3, seconds: 20),
        genre: 'Indie Rock',
        icon: Icons.music_note,
        gradientColors: const [Color(0xFF1DB954), Color(0xFF191414)],
        uploadedAt: DateTime.now(),
        playCount: 0,
      );

      _musicRepository.addSong(nuevaCancion);

      if (subirEnSegundoPlano) {
        // Bloque 6: Programar subida en segundo plano con Workmanager y Notificaciones
        await BackgroundUploadService.programarSubidaEnSegundoPlano(
          albumTitle: album,
        );
      }

      _mensajeExito = 'Tema "$titulo" publicado con éxito.';
      _fotoPortadaPath = null;
      _nombreArchivoAudio = null;
      _subiendo = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al subir tema: $e';
      _subiendo = false;
      notifyListeners();
      return false;
    }
  }

  void limpiarMensajes() {
    _mensajeExito = null;
    _error = null;
    notifyListeners();
  }
}
