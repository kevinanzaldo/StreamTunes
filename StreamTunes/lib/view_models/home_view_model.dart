import 'package:flutter/foundation.dart';

import '../models/artist.dart';
import '../models/band.dart';
import '../models/song.dart';
import '../repositories/interfaces/band_repository.dart';
import '../repositories/interfaces/song_repository.dart';

enum HomeStatus { loading, ready, error }

/// Estado de la pantalla de inicio: bandas y últimos lanzamientos.
///
/// Solo conoce las interfaces de repositorio, así que funciona igual con
/// datos de demo o con Supabase.
class HomeViewModel extends ChangeNotifier {
  // Parámetros nombrados privados (Dart 3.12+): se llaman `songRepository:` y
  // `bandRepository:` desde afuera y se guardan directo en los campos privados.
  HomeViewModel({required this._songRepository, required this._bandRepository});

  final SongRepository _songRepository;
  final BandRepository _bandRepository;

  HomeStatus _status = HomeStatus.loading;
  List<Song> _latestSongs = const [];
  List<Band> _bands = const [];
  final Map<String, Artist> _artistCache = {};
  String _searchQuery = '';
  String? _selectedGenre;
  bool _disposed = false;

  HomeStatus get status => _status;
  List<Song> get latestSongs => List.unmodifiable(_latestSongs);
  List<Band> get bands => List.unmodifiable(_bands);
  String get searchQuery => _searchQuery;
  String? get selectedGenre => _selectedGenre;

  List<String> get availableGenres {
    final genres = _latestSongs
        .map((s) => s.genre.trim())
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList();
    genres.sort();
    return genres;
  }

  List<Song> get filteredSongs {
    return _latestSongs.where((song) {
      final matchesQuery =
          _searchQuery.isEmpty ||
          song.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          song.artistName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesGenre =
          _selectedGenre == null ||
          _selectedGenre == 'Todos' ||
          song.genre.toLowerCase() == _selectedGenre!.toLowerCase();
      return matchesQuery && matchesGenre;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    _notify();
  }

  void selectGenre(String? genre) {
    if (genre == 'Todos' || genre == _selectedGenre) {
      _selectedGenre = null;
    } else {
      _selectedGenre = genre;
    }
    _notify();
  }

  /// Carga inicial (o reintento): muestra el estado "cargando".
  Future<void> load() async {
    _status = HomeStatus.loading;
    _notify();
    await _fetch();
  }

  /// Recarga sin pasar por "cargando" (pull-to-refresh).
  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    try {
      final results = await Future.wait<Object>([
        _songRepository.getLatestSongs(),
        _bandRepository.getApprovedBands(),
      ]);
      _latestSongs = results[0] as List<Song>;
      _bands = results[1] as List<Band>;
      _status = HomeStatus.ready;
    } catch (e, st) {
      debugPrint('HomeViewModel: error cargando el inicio: $e\n$st');
      _status = HomeStatus.error;
    }
    _notify();
  }

  /// Adaptador temporal hacia `ArtistDetailView` (que todavía usa [Artist]).
  /// Devuelve siempre la misma instancia por banda para conservar su estado
  /// (por ejemplo las donaciones acumuladas) mientras dura la sesión.
  Artist artistFor(Band band) {
    return _artistCache.putIfAbsent(band.id, () => Artist.fromBand(band));
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
