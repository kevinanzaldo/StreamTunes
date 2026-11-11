import 'dart:async';

import '../../config/app_constants.dart';
import '../../data/mock_data.dart';
import '../../models/donation.dart';
import '../interfaces/donation_repository.dart';

/// Implementación en memoria (tests y modo demo). Al donar suma el monto al
/// artista de `MockData`, igual que hacía `LibraryViewModel` antes.
class FakeDonationRepository implements DonationRepository {
  final List<Donation> _donations = [];
  final StreamController<Donation> _controller =
      StreamController<Donation>.broadcast();
  bool _spendCapActive = false;
  double _maxDonationArs = kMaxDonationArs;

  void setSpendCapActive(bool active) {
    _spendCapActive = active;
  }

  void setMaxDonationArs(double maxAmount) {
    _maxDonationArs = maxAmount;
  }

  @override
  Future<List<Donation>> getMyDonations() async =>
      List<Donation>.unmodifiable(_donations);

  @override
  Future<List<Donation>> getBandDonations(String bandId) async {
    return List<Donation>.unmodifiable(
      _donations.where((d) => d.artistId == bandId),
    );
  }

  @override
  Stream<Donation> watchBandDonations(String bandId) {
    return _controller.stream.where((d) => d.artistId == bandId);
  }

  @override
  Future<bool> isSpendCapActive() async => _spendCapActive;

  @override
  Future<double> getMaxDonationArs() async => _maxDonationArs;

  @override
  Future<Donation> addDonation(Donation donation) async {
    _donations.insert(0, donation);
    final artist = MockData.getArtistById(donation.artistId);
    if (artist != null) {
      artist.donationsCollected += donation.amount;
    }
    _controller.add(donation);
    return donation;
  }

  void dispose() {
    _controller.close();
  }
}
