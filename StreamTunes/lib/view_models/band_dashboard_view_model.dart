import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';
import '../models/band.dart';
import '../models/donation.dart';
import '../models/metricas_artista.dart';
import '../models/song.dart';
import '../repositories/fake/fake_storage_repository.dart';
import '../repositories/interfaces/band_repository.dart';
import '../repositories/interfaces/donation_repository.dart';
import '../repositories/interfaces/song_repository.dart';
import '../repositories/interfaces/storage_repository.dart';
import '../repositories/music_repository.dart';
import '../services/dispositivo_capacidades.dart';

/// Lógica y estado del panel privado de una banda ("Mi banda").
class BandDashboardViewModel extends ChangeNotifier {
  BandDashboardViewModel({
    required this.band,
    required this.songRepository,
    required this.donationRepository,
    this.bandRepository,
    this.storageRepository,
    MusicRepository? musicRepository,
    DispositivoCapacidades? dispositivoCapacidades,
  }) : _musicRepository = musicRepository ?? MusicRepository(),
       _dispositivoCapacidades =
           dispositivoCapacidades ?? DispositivoCapacidades();

  final Band band;
  final SongRepository songRepository;
  final DonationRepository donationRepository;
  final BandRepository? bandRepository;
  final StorageRepository? storageRepository;
  final MusicRepository _musicRepository;
  final DispositivoCapacidades _dispositivoCapacidades;

  bool _isLoading = true;
  String? _error;
  List<Song> _songs = const [];
  List<Donation> _donations = const [];
  List<Map<String, dynamic>> _topListeners = const [];
  StreamSubscription<Donation>? _donationSub;

  bool _isCalculatingStats = false;
  MetricasArtista? _metrics;
  String? _statsError;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Song> get songs => List.unmodifiable(_songs);
  List<Donation> get donations => List.unmodifiable(_donations);
  List<Map<String, dynamic>> get topListeners =>
      List.unmodifiable(_topListeners);

  bool get isCalculatingStats => _isCalculatingStats;
  MetricasArtista? get metrics => _metrics;
  String? get statsError => _statsError;

  int get songCount => _songs.length;
  static const int maxSongs = kMaxSongsPerBand;
  static const int maxAlbums = kMaxAlbumsPerBand;

  /// Actualiza datos de perfil y portada de la banda sin persistir `data:` URIs
  /// en Supabase cuando falla el Storage.
  Future<({bool coverFailed})> updateBandProfile({
    required Band currentBand,
    required String name,
    required String genre,
    required String location,
    required String bio,
    required double donationGoal,
    SelectedImageFile? selectedImage,
    BandRepository? fallbackBandRepository,
    StorageRepository? fallbackStorageRepository,
  }) async {
    final bandsRepo = bandRepository ?? fallbackBandRepository;
    if (bandsRepo == null) {
      throw StateError(
        'No hay repositorio de bandas para guardar los cambios.',
      );
    }
    final storageRepo = storageRepository ?? fallbackStorageRepository;

    String? newCoverUrl = currentBand.coverUrl;
    var coverFailed = false;
    if (selectedImage != null && storageRepo != null) {
      try {
        final path = await storageRepo.uploadCover(
          bandId: currentBand.id,
          bytes: selectedImage.bytes,
          fileName: selectedImage.name,
        );
        newCoverUrl = storageRepo.getCoverPublicUrl(path);
      } catch (e) {
        if (storageRepo is FakeStorageRepository) {
          // Fallback a data URI únicamente para el modo demo offline.
          final b64 = base64Encode(selectedImage.bytes);
          final mime = selectedImage.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
          newCoverUrl = 'data:$mime;base64,$b64';
        } else {
          debugPrint('Upload cover de banda falló en Storage de Supabase: $e');
          coverFailed = true;
        }
      }
    }

    final updated = currentBand.copyWith(
      name: name,
      genre: genre,
      location: location,
      bio: bio,
      donationGoal: donationGoal,
      coverUrl: newCoverUrl,
    );

    await bandsRepo.updateBand(updated);
    return (coverFailed: coverFailed);
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final results = await Future.wait<Object>([
        songRepository.getSongsByBand(band.id),
        donationRepository.getBandDonations(band.id),
        if (bandRepository != null)
          bandRepository!.getTopListeners(band.id)
        else
          Future.value(const <Map<String, dynamic>>[]),
      ]);
      _songs = results[0] as List<Song>;
      _donations = results[1] as List<Donation>;
      _topListeners = results[2] as List<Map<String, dynamic>>;

      _setupRealtimeDonations();
      _error = null;
    } catch (_) {
      _error = 'No se pudo cargar la información del panel.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _setupRealtimeDonations() {
    _donationSub?.cancel();
    _donationSub = donationRepository.watchBandDonations(band.id).listen((
      donation,
    ) {
      if (!_disposed) {
        final exists = _donations.any((d) => d.id == donation.id);
        if (!exists) {
          _donations = [donation, ..._donations];
          _notify();
        }
      }
    }, onError: (_) {});
  }

  /// Calcula 50.000 registros de métricas en segundo plano usando Isolate/compute (Criterio D3).
  Future<void> calculateMetrics() async {
    _isCalculatingStats = true;
    _statsError = null;
    _notify();

    try {
      final records = _musicRepository.generatePlaybackRecords(
        band.id,
        count: 50000,
      );
      final result = await _dispositivoCapacidades.ejecutarComputoPesado(
        MusicRepository.calculateAdvancedMetrics,
        records,
      );
      _metrics = result;
    } catch (e) {
      _statsError = 'Error calculando métricas: $e';
    } finally {
      _isCalculatingStats = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _donationSub?.cancel();
    super.dispose();
  }
}
