import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../config/app_constants.dart';
import '../models/song.dart';
import '../repositories/app_repositories.dart';
import '../repositories/fake/fake_storage_repository.dart';
import '../repositories/interfaces/song_repository.dart';
import '../repositories/interfaces/storage_repository.dart';
import '../services/background_upload_service.dart';
import '../services/dispositivo_capacidades.dart';

class UploadViewModel extends ChangeNotifier {
  static const String _demoBandId = 'artist_1';
  static const String _demoBandName = 'Los Subterráneos';
  static const Uuid _uuid = Uuid();

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
  String _genero = kSongGenres.first;
  int _songCount = 0;
  int _albumCount = 0;
  bool _cargandoCupos = false;
  bool _subiendo = false;
  bool _notificacionNativaProgramada = false;
  String? _avisoPortada;
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
  String get genero => _genero;
  bool get tienePortada => _fotoPortadaPath != null || _selectedImage != null;
  bool get tieneAudio => _selectedAudio != null || _nombreArchivoAudio != null;
  bool get subiendo => _subiendo;
  bool get notificacionNativaProgramada => _notificacionNativaProgramada;
  String? get avisoPortada => _avisoPortada;
  String? get mensajeExito => _mensajeExito;
  String? get error => _error;
  int get songCount => _songCount;
  int get albumCount => _albumCount;
  bool get cargandoCupos => _cargandoCupos;
  bool get hasReachedSongLimit => _songCount >= kMaxSongsPerBand;
  bool get hasReachedAlbumLimit => _albumCount >= kMaxAlbumsPerBand;

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

  /// Selecciona un género del catálogo permitido.
  void setGenero(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _genero = trimmed;
    _notify();
  }

  /// Limpia todo el formulario para que la siguiente subida empiece vacía.
  void limpiarFormulario() {
    _selectedImage = null;
    _fotoPortadaPath = null;
    _selectedAudio = null;
    _nombreArchivoAudio = null;
    _duracionAudio = null;
    _genero = kSongGenres.first;
    _notificacionNativaProgramada = false;
    _avisoPortada = null;
    _error = null;
    _mensajeExito = null;
    _notify();
  }

  void setDuracionAudio(Duration? dur) {
    _duracionAudio = dur;
    if (dur != null && dur.inSeconds < kMinSongDurationSeconds) {
      _error = 'La canción debe durar al menos 1 minuto (60 segundos).';
    } else {
      _error = null;
    }
    _notify();
  }

  /// Abre el explorador de archivos para elegir un MP3/WAV/M4A real y leer su duración.
  Future<void> seleccionarAudio() async {
    final result = await _dispositivoCapacidades.seleccionarArchivoAudio();
    if (result != null) {
      _selectedAudio = result;
      _nombreArchivoAudio = result.name;
      _duracionAudio = result.duration;
      if (_duracionAudio != null &&
          _duracionAudio!.inSeconds < kMinSongDurationSeconds) {
        _error = 'La canción debe durar al menos 1 minuto (60 segundos).';
      } else {
        _error = null;
      }
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
        duration: duration,
      );
    } else {
      _selectedAudio = null;
    }
    _duracionAudio = duration;
    if (duration != null && duration.inSeconds < kMinSongDurationSeconds) {
      _error = 'La canción debe durar al menos 1 minuto (60 segundos).';
    } else {
      _error = null;
    }
    _notify();
  }

  /// Publica un tema nuevo.
  ///
  /// El cupo ([kMaxSongsPerBand] temas / [kMaxAlbumsPerBand] álbumes por banda)
  /// se valida acá como feedback inmediato; la base vuelve a exigirlo con triggers.
  /// Exige archivo de audio válido y duración mínima de 1 minuto (60 s).
  ///
  /// [artistId] y [artistName] son la banda activa de la sesión. Si no se pasan
  /// (pantalla usada sin sesión, como en los tests) se usa la banda de demo.
  Future<bool> publicarTema({
    required String titulo,
    String album = 'Demo',
    String? genero,
    String? artistId,
    String? artistName,
    Duration? duracion,
    bool subirEnSegundoPlano = true,
    bool permitirSinAudioEnDemo = false,
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

    final tieneBytesAudio =
        _selectedAudio?.bytes != null && _selectedAudio!.bytes!.isNotEmpty;
    final usaExcepcionDemo =
        permitirSinAudioEnDemo && _storageRepository is FakeStorageRepository;
    if (!tieneBytesAudio && !usaExcepcionDemo) {
      _error = 'Elegí un archivo de audio (.mp3, .m4a o .wav).';
      _notify();
      return false;
    }

    final finalDuration =
        duracion ?? _duracionAudio ?? _selectedAudio?.duration;
    if (finalDuration == null || finalDuration.inSeconds <= 0) {
      _error = 'No pudimos leer la duración del audio, probá con otro archivo.';
      _notify();
      return false;
    }
    if (finalDuration.inSeconds < kMinSongDurationSeconds) {
      _error =
          'La canción debe durar al menos 1 minuto ($kMinSongDurationSeconds segundos). Duración actual: ${finalDuration.inSeconds} s.';
      _notify();
      return false;
    }

    _subiendo = true;
    _notificacionNativaProgramada = false;
    _avisoPortada = null;
    _error = null;
    _notify();

    try {
      // Chequeo previo para UX; la regla definitiva la imponen los triggers
      // songs_limit y albums_limit en Supabase.
      final existingSongs = await _songRepository.getSongsByBand(bandId);
      if (existingSongs.length >= kMaxSongsPerBand) {
        _error =
            'Límite de subida alcanzado: máximo $kMaxSongsPerBand temas por banda.';
        return false;
      }

      final existingAlbums = existingSongs
          .map((s) => s.album.trim().toLowerCase())
          .where((alb) => alb.isNotEmpty)
          .toSet();

      final targetAlbum = album.trim().toLowerCase();
      if (targetAlbum.isNotEmpty &&
          !existingAlbums.contains(targetAlbum) &&
          existingAlbums.length >= kMaxAlbumsPerBand) {
        _error =
            'Límite de subida alcanzado: máximo $kMaxAlbumsPerBand álbumes por banda.';
        return false;
      }

      final songId = _uuid.v4();
      final selectedBytes = _selectedAudio?.bytes;
      String audioPath;
      if (selectedBytes != null && selectedBytes.isNotEmpty) {
        audioPath = await _storageRepository.uploadAudio(
          bandId: bandId,
          songId: songId,
          bytes: selectedBytes,
          fileName: _selectedAudio!.name,
        );
      } else {
        // Solo alcanzable cuando permitirSinAudioEnDemo=true con FakeStorageRepository.
        audioPath = '$bandId/$songId.mp3';
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
          if (_storageRepository is FakeStorageRepository) {
            // Fallback a data URI únicamente para el modo demo offline con FakeStorageRepository.
            debugPrint(
              'Upload cover falló en FakeStorageRepository: $e. Usando data URI demo',
            );
            final b64 = base64Encode(_selectedImage!.bytes);
            final mime = _selectedImage!.name.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg';
            coverUrl = 'data:$mime;base64,$b64';
          } else {
            debugPrint('Upload cover falló en Storage de Supabase: $e');
            coverUrl = null;
            _avisoPortada =
                'No se pudo subir la portada; el tema se publicó sin ella.';
          }
        }
      }

      final resolvedGenre = (genero ?? _genero).trim().isNotEmpty
          ? (genero ?? _genero).trim()
          : kSongGenres.first;

      final nuevaCancion = Song(
        id: songId,
        title: titulo.trim(),
        artistId: bandId,
        artistName: bandName,
        album: album.trim(),
        duration: finalDuration,
        genre: resolvedGenre,
        icon: Icons.music_note,
        gradientColors: const [Color(0xFF1DB954), Color(0xFF191414)],
        audioUrl: audioPath,
        coverUrl: coverUrl,
        uploadedAt: DateTime.now(),
        playCount: 0,
      );

      await _songRepository.addSong(nuevaCancion);

      if (subirEnSegundoPlano) {
        // Bloque 6: Programar notificación post-publicación en segundo plano vía Workmanager
        _notificacionNativaProgramada =
            await BackgroundUploadService.programarSubidaEnSegundoPlano(
              songTitle: titulo.trim(),
              albumTitle: album.trim(),
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
      final errLower = e.toString().toLowerCase();
      final isLimitError =
          errLower.contains('limite_alcanzado') ||
          errLower.contains('límite de subida alcanzado') ||
          errLower.contains('limite de subida alcanzado');
      final isAlbumError =
          errLower.contains('album') || errLower.contains('álbum');
      if (isLimitError && isAlbumError) {
        _error =
            'Límite de subida alcanzado: máximo $kMaxAlbumsPerBand álbumes por banda.';
      } else if (isLimitError) {
        _error =
            'Límite de subida alcanzado: máximo $kMaxSongsPerBand temas por banda.';
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
    _avisoPortada = null;
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
