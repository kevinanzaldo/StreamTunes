import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/song.dart';
import '../repositories/app_repositories.dart';
import '../repositories/interfaces/song_repository.dart';
import '../repositories/interfaces/storage_repository.dart';
import '../services/background_upload_service.dart';
import '../services/dispositivo_capacidades.dart';

class UploadViewModel extends ChangeNotifier {
  static const String _demoBandId = 'artist_1';
  static const String _demoBandName = 'Los Subterráneos';

  final DispositivoCapacidades _dispositivoCapacidades;
  final SongRepository _songRepository;
  final StorageRepository _storageRepository;

  bool _tieneCamara = false;
  bool _cargandoCapacidades = false;
  String? _fotoPortadaPath;
  SelectedImageFile? _selectedImage;
  String? _nombreArchivoAudio;
  SelectedAudioFile? _selectedAudio;
  Duration? _duracionAudio;
  int _songCount = 0;
  int _albumCount = 0;
  bool _cargandoCupos = false;
  bool _subiendo = false;
  bool _notificacionNativaProgramada = false;
  String? _mensajeExito;
  String? _error;
  bool _disposed = false;

  UploadViewModel({
    DispositivoCapacidades? dispositivoCapacidades,
    SongRepository? songRepository,
    StorageRepository? storageRepository,
    bool autoInicializar = true,
  }) : _dispositivoCapacidades =
           dispositivoCapacidades ?? DispositivoCapacidades(),
       _songRepository = songRepository ?? AppRepositories.create().songs,
       _storageRepository =
           storageRepository ?? AppRepositories.create().storage {
    if (autoInicializar) {
      inicializarCapacidades();
    }
  }

  bool get tieneCamara => _tieneCamara;
  bool get cargandoCapacidades => _cargandoCapacidades;
  String? get fotoPortadaPath => _fotoPortadaPath;
  SelectedImageFile? get selectedImage => _selectedImage;
  String? get nombreArchivoAudio => _nombreArchivoAudio;
  SelectedAudioFile? get selectedAudio => _selectedAudio;
  Duration? get duracionAudio => _duracionAudio;
  bool get tienePortada => _fotoPortadaPath != null || _selectedImage != null;
  bool get tieneAudio => _selectedAudio != null || _nombreArchivoAudio != null;
  bool get subiendo => _subiendo;
  bool get notificacionNativaProgramada => _notificacionNativaProgramada;
  String? get mensajeExito => _mensajeExito;
  String? get error => _error;
  int get songCount => _songCount;
  int get albumCount => _albumCount;
  bool get cargandoCupos => _cargandoCupos;
  bool get hasReachedSongLimit => _songCount >= 20;
  bool get hasReachedAlbumLimit => _albumCount >= 2;

  /// Consulta asincrónica de capacidades del dispositivo (Bloque 3 - Criterios D1, F1).
  Future<void> inicializarCapacidades() async {
    _cargandoCapacidades = true;
    _notify();

    _tieneCamara = await _dispositivoCapacidades.tieneCamara;
    _cargandoCapacidades = false;
    _notify();
  }

  /// Carga el conteo actual de temas y álbumes para mostrar el cupo en pantalla.
  Future<void> cargarCupos(String bandId) async {
    _cargandoCupos = true;
    _notify();
    try {
      final songs = await _songRepository.getSongsByBand(bandId);
      _songCount = songs.length;
      final albums = songs
          .map((s) => s.album.trim().toLowerCase())
          .where((a) => a.isNotEmpty)
          .toSet();
      _albumCount = albums.length;
    } catch (_) {
      // Ignorar fallo de precarga de cupos
    } finally {
      _cargandoCupos = false;
      _notify();
    }
  }

  Future<void> tomarFotoConCamara() async {
    final result = await _dispositivoCapacidades.tomarFotoArchivo();
    if (result != null) {
      _selectedImage = result;
      _fotoPortadaPath = result.name;
      _error = null;
      _notify();
    }
  }

  Future<void> seleccionarFotoDeGaleria() async {
    final result = await _dispositivoCapacidades.seleccionarFotoArchivo();
    if (result != null) {
      _selectedImage = result;
      _fotoPortadaPath = result.name;
      _error = null;
      _notify();
    }
  }

  void seleccionarFotoManual(SelectedImageFile img) {
    _selectedImage = img;
    _fotoPortadaPath = img.name;
    _error = null;
    _notify();
  }

  /// Quita la foto seleccionada para dejar el tema sin foto propia
  void quitarFoto() {
    _selectedImage = null;
    _fotoPortadaPath = null;
    _notify();
  }

  /// Limpia todo el formulario para que la siguiente subida empiece vacía
  void limpiarFormulario() {
    _selectedImage = null;
    _fotoPortadaPath = null;
    _selectedAudio = null;
    _nombreArchivoAudio = null;
    _duracionAudio = null;
    _notificacionNativaProgramada = false;
    _error = null;
    _mensajeExito = null;
    _notify();
  }

  void setDuracionAudio(Duration? dur) {
    _duracionAudio = dur;
    if (dur != null && dur.inSeconds < 60) {
      _error = 'La canción debe durar al menos 1 minuto (60 segundos).';
    } else {
      _error = null;
    }
    _notify();
  }

  /// Abre el explorador de archivos para elegir un MP3/WAV/M4A real.
  Future<void> seleccionarAudio() async {
    final result = await _dispositivoCapacidades.seleccionarArchivoAudio();
    if (result != null) {
      _selectedAudio = result;
      _nombreArchivoAudio = result.name;
      _error = null;
      _notify();
    }
  }

  void seleccionarArchivoAudio(
    String fileName, {
    Uint8List? bytes,
    int? size,
    Duration? duration,
  }) {
    _nombreArchivoAudio = fileName;
    if (bytes != null) {
      _selectedAudio = SelectedAudioFile(
        name: fileName,
        size: size ?? bytes.length,
        bytes: bytes,
      );
    }
    if (duration != null) {
      _duracionAudio = duration;
      if (duration.inSeconds < 60) {
        _error = 'La canción debe durar al menos 1 minuto (60 segundos).';
      } else {
        _error = null;
      }
    } else {
      _error = null;
    }
    _notify();
  }

  /// Publica un tema nuevo.
  ///
  /// El cupo (20 temas / 2 álbumes por banda) se valida acá para dar un
  /// mensaje claro, y la base de datos lo vuelve a exigir con triggers.
  ///
  /// Exige una duración mínima de 1 minuto (60 s).
  ///
  /// [artistId] y [artistName] son la banda activa de la sesión. Si no se pasan
  /// (pantalla usada sin sesión, como en los tests) se usa la banda de demo.
  Future<bool> publicarTema({
    required String titulo,
    String album = 'Demo',
    String? artistId,
    String? artistName,
    Duration? duracion,
    bool subirEnSegundoPlano = true,
  }) async {
    final bandId = artistId ?? _demoBandId;
    final bandName = artistName ?? _demoBandName;
    // Evita publicar dos veces si se toca el botón durante la validación.
    if (_subiendo) return false;

    if (titulo.trim().isEmpty) {
      _error = 'Ingresa el título del tema';
      _notify();
      return false;
    }

    final finalDuration = duracion ?? _duracionAudio;
    if (finalDuration != null && finalDuration.inSeconds < 60) {
      _error =
          'La canción debe durar al menos 1 minuto (60 segundos). Duración actual: ${finalDuration.inSeconds} s.';
      _notify();
      return false;
    }

    _subiendo = true;
    _notificacionNativaProgramada = false;
    _error = null;
    _notify();

    try {
      // Validación de límites del MVP: máximo 20 temas o 2 álbumes por banda (Criterio A1)
      final existingSongs = await _songRepository.getSongsByBand(bandId);
      if (existingSongs.length >= 20) {
        _error = 'Límite de subida alcanzado: máximo 20 temas por banda.';
        return false;
      }

      final existingAlbums = existingSongs
          .map((s) => s.album.trim().toLowerCase())
          .where((alb) => alb.isNotEmpty)
          .toSet();

      final targetAlbum = album.trim().toLowerCase();
      if (!existingAlbums.contains(targetAlbum) && existingAlbums.length >= 2) {
        _error = 'Límite de subida alcanzado: máximo 2 álbumes por banda.';
        return false;
      }

      final songId = 'song_${DateTime.now().millisecondsSinceEpoch}';
      String audioPath = '$bandId/$songId.mp3';

      if (_selectedAudio != null && _selectedAudio!.bytes != null) {
        audioPath = await _storageRepository.uploadAudio(
          bandId: bandId,
          songId: songId,
          bytes: _selectedAudio!.bytes!,
          fileName: _selectedAudio!.name,
        );
      }

      // Subida de imagen de portada (si seleccionó foto)
      String? coverUrl;
      if (_selectedImage != null && _selectedImage!.bytes.isNotEmpty) {
        try {
          final coverPath = await _storageRepository.uploadCover(
            bandId: bandId,
            bytes: _selectedImage!.bytes,
            fileName: _selectedImage!.name,
          );
          coverUrl = _storageRepository.getCoverPublicUrl(coverPath);
        } catch (e) {
          debugPrint('Upload cover falló en Storage: $e. Usando data URI');
          final b64 = base64Encode(_selectedImage!.bytes);
          final mime = _selectedImage!.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
          coverUrl = 'data:$mime;base64,$b64';
        }
      }

      final nuevaCancion = Song(
        id: songId,
        title: titulo.trim(),
        artistId: bandId,
        artistName: bandName,
        album: album.trim(),
        duration: finalDuration ?? const Duration(minutes: 3, seconds: 20),
        genre: 'Indie Rock',
        icon: Icons.music_note,
        gradientColors: const [Color(0xFF1DB954), Color(0xFF191414)],
        audioUrl: audioPath,
        coverUrl: coverUrl,
        uploadedAt: DateTime.now(),
        playCount: 0,
      );

      await _songRepository.addSong(nuevaCancion);

      if (subirEnSegundoPlano) {
        // Bloque 6: Programar tarea en segundo plano / notificación nativa en móviles
        _notificacionNativaProgramada =
            await BackgroundUploadService.programarSubidaEnSegundoPlano(
              albumTitle: album,
            );
      } else {
        _notificacionNativaProgramada = false;
      }

      _mensajeExito = 'Tema "$titulo" publicado con éxito.';
      _fotoPortadaPath = null;
      _selectedImage = null;
      _nombreArchivoAudio = null;
      _selectedAudio = null;
      _duracionAudio = null;
      _songCount++;
      return true;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('limite_alcanzado') && errStr.contains('album')) {
        _error = 'Límite de subida alcanzado: máximo 2 álbumes por banda.';
      } else if (errStr.contains('limite_alcanzado')) {
        _error = 'Límite de subida alcanzado: máximo 20 temas por banda.';
      } else {
        _error = 'Error al subir tema: $e';
      }
      return false;
    } finally {
      _subiendo = false;
      _notify();
    }
  }

  void limpiarMensajes() {
    _mensajeExito = null;
    _error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
