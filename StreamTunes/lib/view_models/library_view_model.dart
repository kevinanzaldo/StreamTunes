import 'package:flutter/foundation.dart';

import '../models/donation.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../repositories/interfaces/donation_repository.dart';
import '../repositories/interfaces/playlist_repository.dart';

/// Biblioteca del usuario: playlists y donaciones hechas.
///
/// Playlists y donaciones viven en los repositorios (demo o Supabase), que se
/// inyectan siempre desde afuera.
class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel({
    required this.playlistRepository,
    required this.donationRepository,
    bool autoCargar = true,
  }) {
    if (autoCargar) {
      load();
    }
  }

  final PlaylistRepository playlistRepository;
  final DonationRepository donationRepository;

  final List<Playlist> _playlists = [];
  final List<Donation> _donations = [];

  bool _isLoading = false;
  bool _loadFailed = false;
  String? _error;
  bool _disposed = false;

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  List<Donation> get donations => List.unmodifiable(_donations);

  bool get isLoading => _isLoading;

  /// La última carga de la biblioteca falló (para mostrar "Reintentar").
  bool get loadFailed => _loadFailed;

  /// Último error de una acción (crear playlist, agregar tema...).
  String? get error => _error;

  /// Carga (o recarga) playlists y donaciones del usuario.
  Future<void> load() async {
    _isLoading = true;
    _loadFailed = false;
    _error = null;
    _notify();

    try {
      final results = await Future.wait<Object>([
        playlistRepository.getMyPlaylists(),
        donationRepository.getMyDonations(),
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

  /// Crea una playlist. Devuelve `false` si el nombre está vacío o falló
  /// (en ese caso el motivo queda en [error]).
  Future<bool> createPlaylist(String name, {String description = ''}) async {
    if (name.trim().isEmpty) return false;
    _error = null;
    try {
      final created = await playlistRepository.createPlaylist(
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
      await playlistRepository.addSong(playlistId, song);
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
