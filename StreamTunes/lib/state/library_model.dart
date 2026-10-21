import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/donation.dart';
import '../models/playlist.dart';
import '../models/song.dart';

class LibraryModel extends ChangeNotifier {
  final List<Song> _favoriteSongs = [];
  final List<Playlist> _playlists = [];
  final List<Donation> _donations = [];

  LibraryModel() {
    // Inicializar con playlists por defecto
    _playlists.addAll(MockData.getInitialPlaylists());
    // Marcar un par de canciones como favoritas para tener contenido inicial
    if (MockData.songs.isNotEmpty) {
      _favoriteSongs.add(MockData.songs[0]);
      _favoriteSongs.add(MockData.songs[3]);
    }
  }

  List<Song> get favoriteSongs => List.unmodifiable(_favoriteSongs);
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  List<Donation> get donations => List.unmodifiable(_donations);

  bool isFavorite(Song song) {
    return _favoriteSongs.any((s) => s.id == song.id);
  }

  void toggleFavorite(Song song) {
    if (isFavorite(song)) {
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    } else {
      _favoriteSongs.add(song);
    }
    notifyListeners();
  }

  void createPlaylist(String name, {String description = ''}) {
    if (name.trim().isEmpty) return;
    final newPlaylist = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      description: description.trim(),
      coverGradient: [
        const Color(0xFF1DB954),
        Colors.primaries[(_playlists.length + 3) % Colors.primaries.length],
      ],
      icon: Icons.music_note,
    );
    _playlists.insert(0, newPlaylist);
    notifyListeners();
  }

  bool addSongToPlaylist(String playlistId, Song song) {
    try {
      final playlist = _playlists.firstWhere((p) => p.id == playlistId);
      if (!playlist.songs.any((s) => s.id == song.id)) {
        playlist.songs.add(song);
        notifyListeners();
        return true;
      }
      return false; // Ya estaba en la playlist
    } catch (_) {
      return false;
    }
  }

  void removeSongFromPlaylist(String playlistId, String songId) {
    try {
      final playlist = _playlists.firstWhere((p) => p.id == playlistId);
      playlist.songs.removeWhere((s) => s.id == songId);
      notifyListeners();
    } catch (_) {}
  }

  void recordDonation(Donation donation) {
    _donations.insert(0, donation);
    // Actualizar también el monto acumulado del artista
    final artist = MockData.getArtistById(donation.artistId);
    if (artist != null) {
      artist.donationsCollected += donation.amount;
    }
    notifyListeners();
  }

  double get totalDonatedAmount {
    return _donations.fold(0.0, (sum, d) => sum + d.amount);
  }
}
