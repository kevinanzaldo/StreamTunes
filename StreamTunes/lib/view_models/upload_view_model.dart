import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../config/app_constants.dart';
import '../models/song.dart';
import '../repositories/interfaces/song_repository.dart';
import '../repositories/interfaces/storage_repository.dart';
import '../services/background_upload_service.dart';
import '../services/dispositivo_capacidades.dart';

class UploadViewModel extends ChangeNotifier {
  static const String _demoBandId = 'artist_1';
  static const String _demoBandName = 'Los Subterráneos';
  static const Uuid _uuid = Uuid();

  final DispositivoCapacidades _dispositivoCapacidades;
  final SongRepository songRepository;
  final StorageRepository storageRepository;

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
  double _uploadProgress = 0.0;
  bool _puedeReintentar = false;
  bool _notificacionNativaProgramada = false;
  String? _avisoPortada;
  String? _error;
  bool _disposed = false;

  // Último intento guardado para permitir reintentar sin perder los datos cargados.
  String? _ultimoTitulo;
  String _ultimoAlbum = 'Demo';
  String? _ultimoGenero;
  String? _ultimoLyricsLrc;
  String? _ultimoArtistId;
  String? _ultimoArtistName;
  Duration? _ultimoDuracion;
  bool _ultimoSegundoPlano = true;
  bool _ultimoPermitirSinAudioDemo = false;

  UploadViewModel({
    DispositivoCapacidades? dispositivoCapacidades,
    required this.songRepository,
    required this.storageRepository,
    bool autoInicializar = true,
  }) : _dispositivoCapacidades =
           dispositivoCapacidades ?? DispositivoCapacidades() {
    if (autoInicializar) {
      inicializarCapacidades();
    }
  }

  bool get tieneCamara => _tieneCamara;
  bool get cargandoCapacidades => _cargandoCapacidades;
  bool get mostrarAdvertenciaPestanaWeb => _dispositivoCapacidades.esWeb;
  bool get soportaSegundoPlanoNativo =>
      _dispositivoCapacidades.soportaSegundoPlanoNativo;
  String? get fotoPortadaPath => _fotoPortadaPath;
  SelectedImageFile? get selectedImage => _selectedImage;
  String? get nombreArchivoAudio => _nombreArchivoAudio;
  SelectedAudioFile? get selectedAudio => _selectedAudio;
  Duration? get duracionAudio => _duracionAudio;
  String get genero => _genero;
  bool get tienePortada => _fotoPortadaPath != null || _selectedImage != null;
  bool get tieneAudio => _selectedAudio != null || _nombreArchivoAudio != null;
  bool get subiendo => _subiendo;
  double get uploadProgress => _uploadProgress;
  bool get puedeReintentar => _puedeReintentar;
  bool get notificacionNativaProgramada => _notificacionNativaProgramada;
  String? get avisoPortada => _avisoPortada;
  String? get error => _error;
  int get songCount => _songCount;
  int get albumCount => _albumCount;
  bool get cargandoCupos => _cargandoCupos;
  bool get hasReachedSongLimit => _songCount >= kMaxSongsPerBand;

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
      final songs = await songRepository.getSongsByBand(bandId);
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

  String? _validarImagen(SelectedImageFile img) {
    final ext = img.name.contains('.')
        ? img.name.split('.').last.toLowerCase()
        : '';
    if (!kAllowedImageExtensions.contains(ext)) {
      return 'Formato de imagen no permitido ($ext). Usá JPG, PNG o WebP.';
    }
    if (img.bytes.length > kMaxCoverFileSizeBytes) {
      final maxMb = (kMaxCoverFileSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      return 'La portada supera el máximo permitido de $maxMb MB.';
    }
    return null;
  }

  String? _validarAudio(String fileName, int? size) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    if (ext.isEmpty || !kAllowedAudioExtensions.contains(ext)) {
      return 'Formato de audio no válido ($ext). Usá MP3, M4A o WAV.';
    }
    if (size != null && size > kMaxAudioFileSizeBytes) {
      final maxMb = (kMaxAudioFileSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      return 'El archivo supera el límite de $maxMb MB permitido por Supabase Storage en el plan actual. '
          'Un WAV sin comprimir de ~1 GB no entra en este límite: para subirlo es necesario comprimirlo previamente '
          'a MP3/M4A o contar con transcodificación en servidor (o subir temas individuales de hasta $maxMb MB).';
    }
    return null;
  }

  Future<void> tomarFotoConCamara() async {
    final result = await _dispositivoCapacidades.tomarFotoArchivo();
    if (result != null) {
      final validationError = _validarImagen(result);
      if (validationError != null) {
        _error = validationError;
        _notify();
        return;
      }
      _selectedImage = result;
      _fotoPortadaPath = result.name;
      _error = null;
      _notify();
    }
  }

  Future<void> seleccionarFotoDeGaleria() async {
    final result = await _dispositivoCapacidades.seleccionarFotoArchivo();
    if (result != null) {
      final validationError = _validarImagen(result);
      if (validationError != null) {
        _error = validationError;
        _notify();
        return;
      }
      _selectedImage = result;
      _fotoPortadaPath = result.name;
      _error = null;
      _notify();
    }
  }

  /// Quita la foto seleccionada para dejar el tema sin foto propia.
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
    _uploadProgress = 0.0;
    _puedeReintentar = false;
    _notificacionNativaProgramada = false;
    _avisoPortada = null;
    _error = null;
    _notify();
  }

  /// Abre el explorador de archivos para elegir un MP3/WAV/M4A real y leer su duración.
  Future<void> seleccionarAudio() async {
    final result = await _dispositivoCapacidades.seleccionarArchivoAudio();
    if (result != null) {
      final audioErr = _validarAudio(result.name, result.size);
      if (audioErr != null) {
        _error = audioErr;
        _notify();
        return;
      }
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
    final resolvedSize = size ?? bytes?.length;
    final audioErr = _validarAudio(fileName, resolvedSize);
    if (audioErr != null) {
      _error = audioErr;
      _notify();
      return;
    }
    _nombreArchivoAudio = fileName;
    if (bytes != null) {
      _selectedAudio = SelectedAudioFile(
        name: fileName,
        size: resolvedSize ?? bytes.length,
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

  Future<bool> reintentarSubida() async {
    final title = _ultimoTitulo;
    if (title == null || _subiendo) return false;
    return publicarTema(
      titulo: title,
      album: _ultimoAlbum,
      genero: _ultimoGenero,
      lyricsLrc: _ultimoLyricsLrc,
      artistId: _ultimoArtistId,
      artistName: _ultimoArtistName,
      duracion: _ultimoDuracion,
      subirEnSegundoPlano: _ultimoSegundoPlano,
      permitirSinAudioEnDemo: _ultimoPermitirSinAudioDemo,
    );
  }

  /// Publica un tema nuevo validando formato, tamaño, duración y cupos.
  Future<bool> publicarTema({
    required String titulo,
    String album = 'Demo',
    String? genero,
    String? lyricsLrc,
    String? artistId,
    String? artistName,
    Duration? duracion,
    bool subirEnSegundoPlano = true,
    bool permitirSinAudioEnDemo = false,
  }) async {
    _ultimoTitulo = titulo;
    _ultimoAlbum = album;
    _ultimoGenero = genero;
    _ultimoLyricsLrc = lyricsLrc;
    _ultimoArtistId = artistId;
    _ultimoArtistName = artistName;
    _ultimoDuracion = duracion;
    _ultimoSegundoPlano = subirEnSegundoPlano;
    _ultimoPermitirSinAudioDemo = permitirSinAudioEnDemo;

    final bandId = artistId ?? _demoBandId;
    final bandName = artistName ?? _demoBandName;
    if (_subiendo) return false;

    if (titulo.trim().isEmpty) {
      _error = 'Ingresá el título del tema.';
      _notify();
      return false;
    }

    final tieneBytesAudio =
        _selectedAudio?.bytes != null && _selectedAudio!.bytes!.isNotEmpty;
    final usaExcepcionDemo = permitirSinAudioEnDemo && storageRepository.isMock;
    if (!tieneBytesAudio && !usaExcepcionDemo) {
      _error = 'Elegí un archivo de audio (.mp3, .m4a o .wav).';
      _notify();
      return false;
    }

    if (_selectedAudio != null) {
      final audioErr = _validarAudio(
        _selectedAudio!.name,
        _selectedAudio!.size,
      );
      if (audioErr != null) {
        _error = audioErr;
        _notify();
        return false;
      }
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
    _uploadProgress = 0.05;
    _puedeReintentar = false;
    _notificacionNativaProgramada = false;
    _avisoPortada = null;
    _error = null;
    _notify();

    try {
      final existingSongs = await songRepository.getSongsByBand(bandId);
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

      _uploadProgress = 0.15;
      _notify();

      final songId = _uuid.v4();
      final selectedBytes = _selectedAudio?.bytes;
      String audioPath;
      if (selectedBytes != null && selectedBytes.isNotEmpty) {
        audioPath = await storageRepository.uploadAudio(
          bandId: bandId,
          songId: songId,
          bytes: selectedBytes,
          fileName: _selectedAudio!.name,
          onProgress: (p) {
            _uploadProgress = 0.15 + (p * 0.55);
            _notify();
          },
        );
      } else {
        audioPath = '$bandId/$songId.mp3';
      }

      _uploadProgress = 0.72;
      _notify();

      String? coverUrl;
      if (_selectedImage != null && _selectedImage!.bytes.isNotEmpty) {
        try {
          final coverPath = await storageRepository.uploadCover(
            bandId: bandId,
            bytes: _selectedImage!.bytes,
            fileName: _selectedImage!.name,
            onProgress: (p) {
              _uploadProgress = 0.72 + (p * 0.15);
              _notify();
            },
          );
          coverUrl = storageRepository.getCoverPublicUrl(coverPath);
        } catch (e) {
          debugPrint('Upload cover falló en Storage: $e');
          coverUrl = null;
          _avisoPortada =
              'No se pudo subir la portada; el tema se publicó sin ella.';
        }
      }

      _uploadProgress = 0.9;
      _notify();

      final resolvedGenre = (genero ?? _genero).trim().isNotEmpty
          ? (genero ?? _genero).trim()
          : kSongGenres.first;
      final cleanLrc = (lyricsLrc != null && lyricsLrc.trim().isNotEmpty)
          ? lyricsLrc.trim()
          : null;

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
        lyricsLrc: cleanLrc,
        uploadedAt: DateTime.now(),
        playCount: 0,
      );

      await songRepository.addSong(nuevaCancion);

      if (subirEnSegundoPlano) {
        _notificacionNativaProgramada =
            await BackgroundUploadService.programarSubidaEnSegundoPlano(
              songTitle: titulo.trim(),
              albumTitle: album.trim(),
            );
      } else {
        _notificacionNativaProgramada = false;
      }

      _uploadProgress = 1.0;
      _puedeReintentar = false;
      _fotoPortadaPath = null;
      _selectedImage = null;
      _nombreArchivoAudio = null;
      _selectedAudio = null;
      _duracionAudio = null;
      _songCount++;
      return true;
    } catch (e) {
      _uploadProgress = 0.0;
      _puedeReintentar = true;
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
        _puedeReintentar = false;
      } else if (isLimitError) {
        _error =
            'Límite de subida alcanzado: máximo $kMaxSongsPerBand temas por banda.';
        _puedeReintentar = false;
      } else {
        _error = 'Error al subir tema: $e';
      }
      return false;
    } finally {
      _subiendo = false;
      _notify();
    }
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
