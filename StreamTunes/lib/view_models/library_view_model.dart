import 'package:flutter/foundation.dart';

import '../models/donation.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../repositories/app_repositories.dart';
import '../repositories/interfaces/donation_repository.dart';
import '../repositories/interfaces/playlist_repository.dart';

/// Biblioteca del usuario: playlists, favoritos y donaciones hechas.
///
/// Playlists y donaciones viven en los repositorios (demo o Supabase).
/// Los favoritos son solo locales por ahora: la base no tiene tabla de favoritos.
class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel({
    PlaylistRepository? playlistRepository,
    DonationRepository? donationRepository,
    bool autoCargar = true,
  }) : _playlistRepository =
           playlistRepository ?? AppRepositories.create().playlists,
       _donationRepository =
           donationRepository ?? AppRepositories.create().donations {
    if (autoCargar) {
      load();
    }
  }

  final PlaylistRepository _playlistRepository;
  final DonationRepository _donationRepository;

  final List<Song> _favoriteSongs = [];
  final List<Playlist> _playlists = [];
  final List<Donation> _donations = [];

  bool _isLoading = false;
  bool _loadFailed = false;
  String? _error;
  bool _disposed = false;

  List<Song> get favoriteSongs => List.unmodifiable(_favoriteSongs);
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  List<Donation> get donations => List.unmodifiable(_donations);

  bool get isLoading => _isLoading;

  /// La última carga de la biblioteca falló (para mostrar "Reintentar").
  bool get loadFailed => _loadFailed;

  /// Último error de una acción (crear playlist, agregar tema, donar...).
  String? get error => _error;

  double get totalDonatedAmount {
    return _donations.fold(0.0, (sum, d) => sum + d.amount);
  }

  /// Carga (o recarga) playlists y donaciones del usuario.
  Future<void> load() async {
    _isLoading = true;
    _loadFailed = false;
    _error = null;
    _notify();

    try {
      final results = await Future.wait<Object>([
        _playlistRepository.getMyPlaylists(),
        _donationRepository.getMyDonations(),
      ]);
      _playlists
        ..clear()
        ..addAll(results[0] as List<Playlist>);
      _donations
        ..clear()
        ..addAll(results[1] as List<Donation>);
    } catch (e, st) {
      debugPrint('LibraryViewModel: error cargando la biblioteca: $e\n$st');
      _loadFailed = true;
      _error = 'No se pudo cargar tu biblioteca.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  bool isFavorite(Song song) {
    return _favoriteSongs.any((s) => s.id == song.id);
  }

  void toggleFavorite(Song song) {
    if (isFavorite(song)) {
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    } else {
      _favoriteSongs.add(song);
    }
    _notify();
  }

  /// Crea una playlist. Devuelve `false` si el nombre está vacío o falló
  /// (en ese caso el motivo queda en [error]).
  Future<bool> createPlaylist(String name, {String description = ''}) async {
    if (name.trim().isEmpty) return false;
    _error = null;
    try {
      final created = await _playlistRepository.createPlaylist(
        name: name.trim(),
        description: description.trim(),
      );
      _playlists.insert(0, created);
      _notify();
      return true;
    } catch (e, st) {
      debugPrint('LibraryViewModel: error creando playlist: $e\n$st');
      _error = 'No se pudo crear la playlist.';
      _notify();
      return false;
    }
  }

  /// Agrega un tema a una playlist. Devuelve `false` si ya estaba (sin error)
  /// o si falló (con el motivo en [error]).
  Future<bool> addSongToPlaylist(String playlistId, Song song) async {
    _error = null;
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return false;
    final playlist = _playlists[index];
    if (playlist.songs.any((s) => s.id == song.id)) return false;

    try {
      await _playlistRepository.addSong(playlistId, song);
      if (!playlist.songs.any((s) => s.id == song.id)) {
        playlist.songs.add(song);
      }
      _notify();
      return true;
    } catch (e, st) {
      debugPrint('LibraryViewModel: error agregando tema: $e\n$st');
      _error = 'No se pudo agregar el tema a la playlist.';
      _notify();
      return false;
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    _error = null;
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;

    try {
      await _playlistRepository.removeSong(playlistId, songId);
      _playlists[index].songs.removeWhere((s) => s.id == songId);
      _notify();
    } catch (e, st) {
      debugPrint('LibraryViewModel: error quitando tema: $e\n$st');
      _error = 'No se pudo quitar el tema de la playlist.';
      _notify();
    }
  }

  /// Registra una donación. Devuelve `false` si falló (motivo en [error]).
  Future<bool> recordDonation(Donation donation) async {
    _error = null;
    try {
      final saved = await _donationRepository.addDonation(donation);
      _donations.insert(0, saved);
      _notify();
      return true;
    } catch (e, st) {
      debugPrint('LibraryViewModel: error registrando donación: $e\n$st');
      _error = 'No se pudo registrar la donación.';
      _notify();
      return false;
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
