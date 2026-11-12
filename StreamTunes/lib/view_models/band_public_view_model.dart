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
import '../services/pending_follow_service.dart';

/// Estado y lógica de la vista pública de una banda.
class BandPublicViewModel extends ChangeNotifier {
  BandPublicViewModel({
    required this.band,
    required this.songRepository,
    required this.donationRepository,
    this.bandRepository,
    PendingFollowService? pendingFollowService,
  }) : _pendingFollowService = pendingFollowService ?? PendingFollowService();

  final Band band;
  final SongRepository songRepository;
  final DonationRepository donationRepository;
  final BandRepository? bandRepository;
  final PendingFollowService _pendingFollowService;

  bool _isLoading = true;
  String? _error;
  List<Song> _songs = const [];
  List<Donation> _recentDonations = const [];
  List<OyenteTop> _topFans = const [];
  List<BandEvent> _events = const [];
  List<BandPhoto> _photos = const [];
  bool _isFollowing = false;
  bool _followPendingOffline = false;
  int _followersCount = 0;

  bool _spendCapActive = false;
  double _maxDonationArs = kMaxDonationArs;
  Donation? _latestDonationAlert;
  StreamSubscription<Donation>? _donationSub;
  StreamSubscription<void>? _playEventsSub;
  DateTime? _lastRankingRefresh;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Song> get songs => List.unmodifiable(_songs);
  List<Donation> get recentDonations => List.unmodifiable(_recentDonations);
  List<OyenteTop> get topFans => List.unmodifiable(_topFans);
  List<BandEvent> get events => List.unmodifiable(_events);
  List<BandPhoto> get photos => List.unmodifiable(_photos);
  bool get isFollowing => _isFollowing;
  bool get followPendingOffline => _followPendingOffline;
  int get followersCount => _followersCount;

  bool get spendCapActive => _spendCapActive;
  double get maxDonationArs => _maxDonationArs;
  List<double> get donationAmounts {
    final filtered = kDonationAmountsArs
        .where((amount) => amount <= _maxDonationArs)
        .toList();
    if (filtered.isNotEmpty) return filtered;
    return [_maxDonationArs];
  }

  Donation? get latestDonationAlert => _latestDonationAlert;

  void dismissAlert() {
    _latestDonationAlert = null;
    _notify();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final list = await songRepository.getSongsByBand(band.id);
      final sorted = List<Song>.from(list)
        ..sort((a, b) => b.playCount.compareTo(a.playCount));
      _songs = sorted;

      _recentDonations = (await donationRepository.getBandDonations(band.id))
          .where((d) => d.isApproved)
          .toList();
      _spendCapActive = await donationRepository.isSpendCapActive();
      _maxDonationArs = await donationRepository.getMaxDonationArs();

      if (bandRepository != null) {
        final extras = await Future.wait<Object>([
          bandRepository!.getBandTopFans(band.id),
          bandRepository!.getBandEvents(band.id),
          bandRepository!.getBandPhotos(band.id),
          bandRepository!.isFollowingBand(band.id),
          bandRepository!.getFollowersCount(band.id),
        ]);
        _topFans = extras[0] as List<OyenteTop>;
        _events = extras[1] as List<BandEvent>;
        _photos = extras[2] as List<BandPhoto>;
        _isFollowing = extras[3] as bool;
        _followersCount = extras[4] as int;
      }

      _followPendingOffline = await _pendingFollowService.hasPendingFollow(
        band.id,
      );
      if (_followPendingOffline) {
        _isFollowing = true;
      }

      _setupRealtimeSubscriptions();
      _error = null;
    } catch (e) {
      _error = 'No se pudieron cargar los temas de la banda.';
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
        final exists = _recentDonations.any((d) => d.id == donation.id);
        if (!exists) {
          _recentDonations = [donation, ..._recentDonations];
        }
        _latestDonationAlert = donation;
        _notify();
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

  /// Sigue o deja de seguir a la banda. Si no hay sesión, solicita crear sesión
  /// anónima mediante [ensureAnonymousSession] (sin pedir email). Si no hay
  /// señal, encola la acción localmente para sincronizar al volver la conexión.
  Future<({bool following, bool queuedOffline})> toggleFollow({
    Future<bool> Function()? ensureAnonymousSession,
  }) async {
    if (bandRepository == null) {
      _isFollowing = !_isFollowing;
      _followersCount += _isFollowing ? 1 : -1;
      if (_followersCount < 0) _followersCount = 0;
      _notify();
      return (following: _isFollowing, queuedOffline: false);
    }

    if (_isFollowing) {
      try {
        await bandRepository!.unfollowBand(band.id);
        await _pendingFollowService.removePendingFollow(band.id);
        _isFollowing = false;
        _followPendingOffline = false;
        if (_followersCount > 0) _followersCount--;
        _notify();
        return (following: false, queuedOffline: false);
      } catch (_) {
        await _pendingFollowService.removePendingFollow(band.id);
        _isFollowing = false;
        _followPendingOffline = false;
        _notify();
        return (following: false, queuedOffline: true);
      }
    }

    try {
      if (ensureAnonymousSession != null) {
        final hasSession = await ensureAnonymousSession();
        if (!hasSession) throw StateError('offline');
      }
      await bandRepository!.followBand(band.id);
      await _pendingFollowService.removePendingFollow(band.id);
      _isFollowing = true;
      _followPendingOffline = false;
      _followersCount++;
      _notify();
      return (following: true, queuedOffline: false);
    } catch (_) {
      await _pendingFollowService.queueFollow(band.id);
      _isFollowing = true;
      _followPendingOffline = true;
      _followersCount++;
      _notify();
      return (following: true, queuedOffline: true);
    }
  }

  Future<bool> donate({
    required double amount,
    String? message,
    bool isPublic = true,
  }) async {
    if (amount <= 0 || amount > _maxDonationArs) {
      return false;
    }
    try {
      await donationRepository.addDonation(
        Donation(
          id: 'don_${DateTime.now().millisecondsSinceEpoch}',
          artistId: band.id,
          artistName: band.name,
          amount: amount,
          message: message,
          paymentMethod: 'Pasarela externa',
          isPublic: isPublic,
          status: DonationStatus.approved,
        ),
      );
      return true;
    } catch (_) {
      return false;
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
