import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';
import '../models/band.dart';
import '../models/donation.dart';
import '../models/song.dart';
import '../repositories/interfaces/donation_repository.dart';
import '../repositories/interfaces/song_repository.dart';

/// Estado y lógica de la vista pública de una banda.
class BandPublicViewModel extends ChangeNotifier {
  BandPublicViewModel({
    required this.band,
    required this.songRepository,
    required this.donationRepository,
  });

  final Band band;
  final SongRepository songRepository;
  final DonationRepository donationRepository;

  bool _isLoading = true;
  String? _error;
  List<Song> _songs = const [];
  List<Donation> _recentDonations = const [];
  bool _spendCapActive = false;
  double _maxDonationArs = kMaxDonationArs;
  Donation? _latestDonationAlert;
  StreamSubscription<Donation>? _donationSub;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Song> get songs => List.unmodifiable(_songs);
  List<Donation> get recentDonations => List.unmodifiable(_recentDonations);
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
      // Ordenar por reproducciones descendente (más escuchados primero)
      final sorted = List<Song>.from(list)
        ..sort((a, b) => b.playCount.compareTo(a.playCount));
      _songs = sorted;

      // Cargar donaciones, estado de tope de gastos y monto máximo desde app_config
      _recentDonations = await donationRepository.getBandDonations(band.id);
      _spendCapActive = await donationRepository.isSpendCapActive();
      _maxDonationArs = await donationRepository.getMaxDonationArs();

      _setupRealtimeDonations();
      _error = null;
    } catch (e) {
      _error = 'No se pudieron cargar los temas de la banda.';
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
        final exists = _recentDonations.any((d) => d.id == donation.id);
        if (!exists) {
          _recentDonations = [donation, ..._recentDonations];
        }
        _latestDonationAlert = donation;
        _notify();
      }
    }, onError: (_) {});
  }

  Future<bool> donate({required double amount, String? message}) async {
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
          paymentMethod: 'MercadoPago Simulado',
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
    super.dispose();
  }
}
