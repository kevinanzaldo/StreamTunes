import '../../data/mock_data.dart';
import '../../models/artist.dart';
import '../../models/band.dart';
import '../../models/band_member.dart';
import '../../models/band_membership.dart';
import '../interfaces/band_repository.dart';
import '../interfaces/repository_failure.dart';

/// Implementación en memoria basada en `MockData.artists` (tests y modo demo).
///
/// Cada artista de `MockData` es una banda aprobada cuyo dueño es el usuario
/// `user_<id del artista>` (ver `FakeAuthRepository`).
class FakeBandRepository implements BandRepository {
  final List<Band> _created = [];

  @override
  Future<List<Band>> getApprovedBands() async {
    final bands = [
      ...MockData.artists.map(_fromArtist),
      ..._created.where((b) => b.isApproved),
    ];
    return List.unmodifiable(bands);
  }

  @override
  Future<List<Band>> getBandsByStatus(BandStatus status) async {
    final bands = [...MockData.artists.map(_fromArtist), ..._created];
    return List.unmodifiable(bands.where((b) => b.status == status));
  }

  @override
  Future<void> updateBandStatus(String bandId, BandStatus status) async {
    for (var i = 0; i < _created.length; i++) {
      if (_created[i].id == bandId) {
        _created[i] = _created[i].copyWith(status: status);
        return;
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTopListeners(
    String bandId, {
    int days = 30,
  }) async {
    return const [
      {'display_name': 'Caro Gómez', 'minutes': 142},
      {'display_name': 'Ana Pérez', 'minutes': 89},
      {'display_name': 'Beto Rocker', 'minutes': 47},
    ];
  }

  @override
  Future<Band?> getBandById(String id) async {
    for (final artist in MockData.artists) {
      if (artist.id == id) return _fromArtist(artist);
    }
    for (final band in _created) {
      if (band.id == id) return band;
    }
    return null;
  }

  @override
  Future<Band> createBand(Band band) async {
    final slugTomado =
        MockData.artists.any((a) => Band.slugify(a.name) == band.slug) ||
        _created.any((b) => b.slug == band.slug);
    if (slugTomado) {
      throw const RepositoryFailure('Ya existe una banda con ese nombre.');
    }

    final pending = Band(
      id: 'band_${_created.length + 1}',
      slug: band.slug,
      name: band.name,
      bio: band.bio,
      genre: band.genre,
      location: band.location,
      coverUrl: band.coverUrl,
      socialLinks: band.socialLinks,
      donationGoal: band.donationGoal,
      status: BandStatus.pending,
      createdBy: band.createdBy,
      createdAt: DateTime.now(),
    );
    _created.add(pending);
    return pending;
  }

  @override
  Future<Band> updateBand(Band band) async {
    for (var i = 0; i < _created.length; i++) {
      if (_created[i].id == band.id) {
        _created[i] = band;
        return band;
      }
    }
    _created.add(band);
    return band;
  }

  @override
  Future<List<BandMembership>> getMyMemberships(String userId) async {
    return [
      for (final artist in MockData.artists)
        if ('user_${artist.id}' == userId)
          BandMembership(band: _fromArtist(artist), role: MemberRole.owner),
      for (final band in _created)
        if (band.createdBy == userId)
          BandMembership(band: band, role: MemberRole.owner),
    ];
  }

  Band _fromArtist(Artist artist) {
    return Band(
      id: artist.id,
      slug: Band.slugify(artist.name),
      name: artist.name,
      bio: artist.bio,
      genre: artist.genre,
      location: artist.location,
      socialLinks: artist.socialLinks,
      donationGoal: artist.donationGoal,
      donationsCollected: artist.donationsCollected,
      status: BandStatus.approved,
      createdBy: 'user_${artist.id}',
      createdAt: DateTime(2026, 1, 1),
    );
  }
}
