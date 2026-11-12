import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';
import '../models/band.dart';
import '../models/band_event.dart';
import '../models/band_photo.dart';
import '../models/donation.dart';
import '../models/metricas_artista.dart';
import '../models/song.dart';
import '../repositories/interfaces/band_repository.dart';
import '../repositories/interfaces/donation_repository.dart';
import '../repositories/interfaces/song_repository.dart';
import '../repositories/interfaces/storage_repository.dart';
import '../services/dispositivo_capacidades.dart';

/// Lógica y estado del panel privado de una banda ("Mi banda").
class BandDashboardViewModel extends ChangeNotifier {
  BandDashboardViewModel({
    required this.band,
    required this.songRepository,
    required this.donationRepository,
    this.bandRepository,
    this.storageRepository,
    DispositivoCapacidades? dispositivoCapacidades,
  }) : _dispositivoCapacidades =
           dispositivoCapacidades ?? DispositivoCapacidades();

  final Band band;
  final SongRepository songRepository;
  final DonationRepository donationRepository;
  final BandRepository? bandRepository;
  final StorageRepository? storageRepository;
  final DispositivoCapacidades _dispositivoCapacidades;

  bool _isLoading = true;
  String? _error;
  List<Song> _songs = const [];
  List<Donation> _donations = const [];
  List<OyenteTop> _topFans = const [];
  List<BandEvent> _events = const [];
  List<BandPhoto> _photos = const [];
  int _followersCount = 0;

  StreamSubscription<Donation>? _donationSub;
  StreamSubscription<void>? _playEventsSub;
  DateTime? _lastRankingRefresh;

  bool _isCalculatingStats = false;
  MetricasArtista? _metrics;
  String? _statsError;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Song> get songs => List.unmodifiable(_songs);
  List<Donation> get donations => List.unmodifiable(_donations);
  List<OyenteTop> get topFans => List.unmodifiable(_topFans);
  List<BandEvent> get events => List.unmodifiable(_events);
  List<BandPhoto> get photos => List.unmodifiable(_photos);
  int get followersCount => _followersCount;

  /// Deep link de perfil público codificado en el QR offline de la banda.
  String get qrDeepLink => buildBandQrUrl(band.slug);

  bool get isCalculatingStats => _isCalculatingStats;
  MetricasArtista? get metrics => _metrics;
  String? get statsError => _statsError;

  int get songCount => _songs.length;
  static const int maxSongs = kMaxSongsPerBand;

  /// Actualiza datos de perfil, enlace de merch y portada de la banda.
  Future<({bool coverFailed})> updateBandProfile({
    required Band currentBand,
    required String name,
    required String genre,
    required String location,
    required String bio,
    required double donationGoal,
    String? merchUrl,
    SelectedImageFile? selectedImage,
  }) async {
    final bandsRepo = bandRepository;
    if (bandsRepo == null) {
      throw StateError(
        'No hay repositorio de bandas para guardar los cambios.',
      );
    }
    final storageRepo = storageRepository;

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
        debugPrint('Upload cover de banda falló en Storage: $e');
        coverFailed = true;
      }
    }

    final cleanMerch = merchUrl?.trim();
    final updated = currentBand.copyWith(
      name: name,
      genre: genre,
      location: location,
      bio: bio,
      donationGoal: donationGoal,
      coverUrl: newCoverUrl,
      merchUrl: cleanMerch != null && cleanMerch.isNotEmpty ? cleanMerch : null,
    );

    await bandsRepo.updateBand(updated);
    return (coverFailed: coverFailed);
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      try {
        _songs = await songRepository.getSongsByBand(band.id);
      } catch (e) {
        debugPrint('Error cargando songs en dashboard: $e');
        _songs = const [];
      }

      try {
        _donations = await donationRepository.getBandDonations(band.id);
      } catch (e) {
        debugPrint('Error cargando donaciones en dashboard: $e');
        _donations = const [];
      }

      if (bandRepository != null) {
        try {
          _topFans = await bandRepository!.getBandTopFans(band.id);
        } catch (_) {
          _topFans = const [];
        }
        try {
          _events = await bandRepository!.getBandEvents(band.id);
        } catch (_) {
          _events = const [];
        }
        try {
          _photos = await bandRepository!.getBandPhotos(band.id);
        } catch (_) {
          _photos = const [];
        }
        try {
          _followersCount = await bandRepository!.getFollowersCount(band.id);
        } catch (_) {
          _followersCount = 0;
        }
      }

      _setupRealtimeSubscriptions();
      _error = null;
    } catch (e) {
      debugPrint('Error general en dashboard load: $e');
      _error = 'No se pudo cargar la información del panel.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _setupRealtimeSubscriptions() {
    _donationSub?.cancel();
    _donationSub = donationRepository.watchBandDonations(band.id).listen((
      donation,
    ) {
      if (!_disposed && donation.isApproved) {
        final exists = _donations.any((d) => d.id == donation.id);
        if (!exists) {
          _donations = [donation, ..._donations];
          _notify();
        }
      }
    }, onError: (_) {});

    _playEventsSub?.cancel();
    if (bandRepository != null) {
      _playEventsSub = bandRepository!.watchBandPlayEvents(band.id).listen((_) {
        _throttledRefreshTopFans();
      }, onError: (_) {});
    }
  }

  Future<void> _throttledRefreshTopFans() async {
    if (_disposed || bandRepository == null) return;
    final now = DateTime.now();
    if (_lastRankingRefresh != null &&
        now.difference(_lastRankingRefresh!) < kRealtimeRankingThrottle) {
      return;
    }
    _lastRankingRefresh = now;
    try {
      _topFans = await bandRepository!.getBandTopFans(band.id);
      _notify();
    } catch (_) {}
  }

  /// Obtiene las estadísticas globales agregadas en el SERVIDOR Postgres
  /// (`band_aggregated_stats` / `band_top_fans`).
  /// Solo si no hay repositorio con RPC disponible, formatea localmente las
  /// series ya descargadas mediante `DispositivoCapacidades.ejecutarComputoPesado`
  /// (que en Web corre en el hilo principal y no resuelve carga pesada).
  Future<void> calculateMetrics() async {
    _isCalculatingStats = true;
    _statsError = null;
    _notify();

    try {
      if (bandRepository != null) {
        final serverStats = await bandRepository!.getBandAggregatedStats(
          band.id,
        );
        if (serverStats.totalReproducciones > 0 ||
            serverStats.topTemas.isNotEmpty) {
          // Ordenamiento/formateo local opcional de series pequeñas ya agregadas.
          _metrics = await _dispositivoCapacidades.ejecutarComputoPesado(
            _ordenarSeriesServidor,
            serverStats,
          );
          _topFans = serverStats.rankingOyentes;
          return;
        }
      }

      List<Map<String, dynamic>> playEvents = const [];
      try {
        playEvents = await songRepository.getPlayEventsByBand(band.id);
      } catch (e) {
        debugPrint('No se pudieron cargar play_events para métricas: $e');
      }

      if (playEvents.isEmpty) {
        _metrics = MetricasArtista.empty;
      } else {
        final songTitlesById = <String, String>{
          for (final song in _songs) song.id: song.title,
        };
        final input = SeriesProcesadasInput(
          playEvents: playEvents,
          songTitlesById: songTitlesById,
        );
        _metrics = await _dispositivoCapacidades.ejecutarComputoPesado(
          procesarMetricasReales,
          input,
        );
      }
    } catch (e) {
      _statsError = 'Error calculando métricas: $e';
    } finally {
      _isCalculatingStats = false;
      _notify();
    }
  }

  Future<bool> addEvent({
    required String title,
    required String venue,
    String city = '',
    required DateTime eventDate,
    String? ticketUrl,
  }) async {
    final repo = bandRepository;
    if (repo == null) return false;
    try {
      final created = await repo.addBandEvent(
        BandEvent(
          id: '',
          bandId: band.id,
          title: title,
          venue: venue,
          city: city,
          eventDate: eventDate,
          ticketUrl: ticketUrl,
        ),
      );
      _events = [..._events, created]
        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
      _notify();
      return true;
    } catch (e) {
      debugPrint('Error agregando evento de banda: $e');
      return false;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final repo = bandRepository;
    if (repo == null) return;
    try {
      await repo.deleteBandEvent(eventId);
      _events = _events.where((e) => e.id != eventId).toList();
      _notify();
    } catch (e) {
      debugPrint('Error borrando evento de banda: $e');
    }
  }

  Future<bool> addShowPhoto(SelectedImageFile image, {String? caption}) async {
    final bandsRepo = bandRepository;
    final storageRepo = storageRepository;
    if (bandsRepo == null || storageRepo == null) return false;
    try {
      final path = await storageRepo.uploadCover(
        bandId: band.id,
        bytes: image.bytes,
        fileName: image.name,
      );
      final publicUrl = storageRepo.getCoverPublicUrl(path);
      final created = await bandsRepo.addBandPhoto(
        BandPhoto(
          id: '',
          bandId: band.id,
          photoUrl: publicUrl,
          caption: caption,
          createdAt: DateTime.now(),
        ),
      );
      _photos = [created, ..._photos];
      _notify();
      return true;
    } catch (e) {
      debugPrint('Error subiendo foto de show: $e');
      return false;
    }
  }

  Future<void> deleteShowPhoto(String photoId) async {
    final repo = bandRepository;
    if (repo == null) return;
    try {
      await repo.deleteBandPhoto(photoId);
      _photos = _photos.where((p) => p.id != photoId).toList();
      _notify();
    } catch (e) {
      debugPrint('Error borrando foto de show: $e');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _donationSub?.cancel();
    _playEventsSub?.cancel();
    super.dispose();
  }
}

MetricasArtista _ordenarSeriesServidor(MetricasArtista stats) {
  final temasOrdenados = List<TemaMetrica>.from(stats.topTemas)
    ..sort((a, b) => b.reproducciones.compareTo(a.reproducciones));
  final diasOrdenados = List<DiaMetrica>.from(stats.reproduccionesPorDia)
    ..sort((a, b) => b.fecha.compareTo(a.fecha));
  return MetricasArtista(
    totalMinutos: stats.totalMinutos,
    totalReproducciones: stats.totalReproducciones,
    rankingOyentes: stats.rankingOyentes,
    topTemas: temasOrdenados,
    reproduccionesPorDia: diasOrdenados,
    totalEventosReales: stats.totalEventosReales,
  );
}

/// DTO para transferir series descargadas al hilo secundario / worker.
class SeriesProcesadasInput {
  final List<Map<String, dynamic>> playEvents;
  final Map<String, String> songTitlesById;

  const SeriesProcesadasInput({
    required this.playEvents,
    required this.songTitlesById,
  });
}

/// Procesa localmente series ya descargadas.
/// En Web corre en el hilo principal mediante `compute`; en nativo en `Isolate`.
MetricasArtista procesarMetricasReales(SeriesProcesadasInput input) {
  if (input.playEvents.isEmpty) {
    return MetricasArtista.empty;
  }

  int totalSeconds = 0;
  final playsBySong = <String, int>{};
  final secondsBySong = <String, int>{};
  final playsByDay = <String, int>{};
  final secondsByDay = <String, int>{};
  final secondsByUser = <String, int>{};
  final nameByUser = <String, String>{};
  final avatarByUser = <String, String?>{};
  final publicByUser = <String, bool>{};
  final cityByUser = <String, String>{};

  for (final event in input.playEvents) {
    final seconds = (event['seconds_listened'] as num?)?.toInt() ?? 0;
    if (seconds <= 0) continue;
    totalSeconds += seconds;

    final songId = (event['song_id'] as String?) ?? '';
    if (songId.isNotEmpty) {
      playsBySong[songId] = (playsBySong[songId] ?? 0) + 1;
      secondsBySong[songId] = (secondsBySong[songId] ?? 0) + seconds;
    }

    final createdAtStr = event['created_at'] as String?;
    final dt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
    if (dt != null) {
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final dayKey = '${dt.year}-$month-$day';
      playsByDay[dayKey] = (playsByDay[dayKey] ?? 0) + 1;
      secondsByDay[dayKey] = (secondsByDay[dayKey] ?? 0) + seconds;
    }

    final rawUserId = event['user_id'] as String?;
    final profile = event['profiles'];
    final profileName = profile is Map
        ? (profile['display_name'] as String?)
        : null;
    final profileAvatar = profile is Map
        ? (profile['avatar_url'] as String?)
        : null;
    final isPublic = profile is Map
        ? (profile['is_public_profile'] as bool? ?? false)
        : false;
    final explicitName = (event['display_name'] as String?) ?? profileName;

    final key = (rawUserId != null && rawUserId.isNotEmpty)
        ? rawUserId
        : 'anon_${explicitName ?? 'user'}';
    secondsByUser[key] = (secondsByUser[key] ?? 0) + seconds;
    publicByUser[key] = isPublic;

    if (isPublic && explicitName != null && explicitName.trim().isNotEmpty) {
      nameByUser[key] = explicitName.trim();
      avatarByUser[key] = profileAvatar;
    } else {
      nameByUser[key] = 'Fan anónimo';
      avatarByUser[key] = null;
    }

    final city = (event['city'] as String?)?.trim() ?? '';
    if (isPublic && city.isNotEmpty && !cityByUser.containsKey(key)) {
      cityByUser[key] = city;
    }
  }

  final topTemas = playsBySong.entries.map((entry) {
    return TemaMetrica(
      songId: entry.key,
      titulo: input.songTitlesById[entry.key] ?? entry.key,
      reproducciones: entry.value,
      minutos: (secondsBySong[entry.key] ?? 0) ~/ 60,
    );
  }).toList()..sort((a, b) => b.reproducciones.compareTo(a.reproducciones));

  final diasOrdenados = playsByDay.entries.map((entry) {
    return DiaMetrica(
      fecha: entry.key,
      reproducciones: entry.value,
      minutos: (secondsByDay[entry.key] ?? 0) ~/ 60,
    );
  }).toList()..sort((a, b) => b.fecha.compareTo(a.fecha));

  final ranking = secondsByUser.entries.map((entry) {
    return OyenteTop(
      nombre: nameByUser[entry.key] ?? 'Fan anónimo',
      minutos: (entry.value / 60).round().clamp(1, 1000000),
      ubicacion: cityByUser[entry.key] ?? '',
      avatarUrl: avatarByUser[entry.key],
      isPublic: publicByUser[entry.key] ?? false,
    );
  }).toList()..sort((a, b) => b.minutos.compareTo(a.minutos));

  return MetricasArtista(
    totalMinutos: totalSeconds ~/ 60,
    totalReproducciones: input.playEvents.length,
    rankingOyentes: ranking.take(10).toList(),
    topTemas: topTemas.take(5).toList(),
    reproduccionesPorDia: diasOrdenados.take(7).toList(),
    totalEventosReales: input.playEvents.length,
  );
}
