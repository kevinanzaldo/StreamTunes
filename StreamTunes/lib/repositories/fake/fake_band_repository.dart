import 'dart:async';

import '../../models/band.dart';
import '../../models/band_event.dart';
import '../../models/band_member.dart';
import '../../models/band_membership.dart';
import '../../models/band_photo.dart';
import '../../models/metricas_artista.dart';
import '../interfaces/band_repository.dart';
import '../interfaces/repository_failure.dart';

/// Implementación en memoria para `flutter test` y desarrollo sin credenciales.
class FakeBandRepository implements BandRepository {
  FakeBandRepository({
    List<Band>? initialBands,
    Map<String, MetricasArtista>? initialStats,
    Map<String, List<OyenteTop>>? initialTopFans,
    List<BandEvent>? initialEvents,
    List<BandPhoto>? initialPhotos,
  }) {
    _bands.addAll(initialBands ?? _defaultBands);
    if (initialStats != null) _statsByBand.addAll(initialStats);
    if (initialTopFans != null) _topFansByBand.addAll(initialTopFans);
    if (initialEvents != null) _events.addAll(initialEvents);
    if (initialPhotos != null) _photos.addAll(initialPhotos);
  }

  static final List<Band> _defaultBands = [
    Band(
      id: 'artist_1',
      slug: 'los-subterraneos',
      name: 'Los Subterráneos',
      bio: 'Banda oriunda de Buenos Aires explorando texturas de guitarras analógicas, letras introspectivas y sonidos de garage.',
      genre: 'Indie Rock',
      location: 'Buenos Aires, AR',
      donationGoal: 60000.0,
      donationsCollected: 34500.0,
      status: BandStatus.approved,
      createdBy: 'user_artist_1',
      createdAt: DateTime(2026, 1, 1),
    ),
    Band(
      id: 'artist_2',
      slug: 'banda-fractal',
      name: 'Banda Fractal',
      bio: 'Dúo experimental que fusiona sintetizadores retro de los 80 con ritmos electrónicos futuristas y voces etéreas.',
      genre: 'Synthwave / Indie Pop',
      location: 'Córdoba, AR',
      donationGoal: 45000.0,
      donationsCollected: 29000.0,
      status: BandStatus.approved,
      createdBy: 'user_artist_2',
      createdAt: DateTime(2026, 1, 1),
    ),
    Band(
      id: 'artist_3',
      slug: 'terapia-de-choque',
      name: 'Terapia de Choque',
      bio: 'Sonido crudo, baterías potentes y líneas de bajo oscuras que capturan la energía urbana nocturna.',
      genre: 'Post-Punk / Alternativo',
      location: 'Rosario, AR',
      donationGoal: 30000.0,
      donationsCollected: 18200.0,
      status: BandStatus.approved,
      createdBy: 'user_artist_3',
      createdAt: DateTime(2026, 1, 1),
    ),
    Band(
      id: 'artist_4',
      slug: 'vientos-nomadas',
      name: 'Vientos Nómadas',
      bio: 'Canciones acústicas de raíz folclórica con charango, quena y arreglos corales grabados en la cordillera.',
      genre: 'Folk Acústico / Andino',
      location: 'Mendoza, AR',
      donationGoal: 50000.0,
      donationsCollected: 41000.0,
      status: BandStatus.approved,
      createdBy: 'user_artist_4',
      createdAt: DateTime(2026, 1, 1),
    ),
    Band(
      id: 'artist_5',
      slug: 'cumbia-cosmica',
      name: 'Cumbia Cósmica',
      bio: 'Pioneros en mezclar la cumbia villera tradicional con sintetizadores espaciales y cadencias psicodélicas.',
      genre: 'Cumbia Indie / Dub',
      location: 'La Plata, AR',
      donationGoal: 80000.0,
      donationsCollected: 52000.0,
      status: BandStatus.approved,
      createdBy: 'user_artist_5',
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  final List<Band> _bands = [];
  final Map<String, MetricasArtista> _statsByBand = {};
  final Map<String, List<OyenteTop>> _topFansByBand = {};
  final List<BandEvent> _events = [];
  final List<BandPhoto> _photos = [];
  final Map<String, int> _followersCount = {};
  final Set<String> _followedBands = {};
  final StreamController<String> _playEventsController =
      StreamController<String>.broadcast();

  @override
  Future<List<Band>> getApprovedBands() async {
    return List.unmodifiable(_bands.where((b) => b.isApproved));
  }

  @override
  Future<List<Band>> getBandsByStatus(BandStatus status) async {
    return List.unmodifiable(_bands.where((b) => b.status == status));
  }

  @override
  Future<void> updateBandStatus(String bandId, BandStatus status) async {
    for (var i = 0; i < _bands.length; i++) {
      if (_bands[i].id == bandId) {
        _bands[i] = _bands[i].copyWith(status: status);
        return;
      }
    }
  }

  @override
  Future<MetricasArtista> getBandAggregatedStats(String bandId) async {
    return _statsByBand[bandId] ?? MetricasArtista.empty;
  }

  @override
  Future<List<OyenteTop>> getBandTopFans(String bandId, {int days = 30}) async {
    final fans = _topFansByBand[bandId] ?? const <OyenteTop>[];
    return fans
        .take(10)
        .map(
          (f) => f.isPublic
              ? f
              : OyenteTop(
                  nombre: 'Fan anónimo',
                  minutos: f.minutos,
                  avatarUrl: null,
                  isPublic: false,
                ),
        )
        .toList();
  }

  @override
  Stream<void> watchBandPlayEvents(String bandId) {
    return _playEventsController.stream.where((id) => id == bandId).map((_) {});
  }

  @override
  Future<Band?> getBandById(String id) async {
    for (final band in _bands) {
      if (band.id == id) return band;
    }
    return null;
  }

  @override
  Future<Band?> getBandBySlug(String slug) async {
    for (final band in _bands) {
      if (band.slug == slug) return band;
    }
    return null;
  }

  @override
  Future<Band> createBand(Band band) async {
    final slugTomado = _bands.any((b) => b.slug == band.slug);
    if (slugTomado) {
      throw const RepositoryFailure('Ya existe una banda con ese nombre.');
    }

    final pending = Band(
      id: 'band_${_bands.length + 1}',
      slug: band.slug,
      name: band.name,
      bio: band.bio,
      genre: band.genre,
      location: band.location,
      coverUrl: band.coverUrl,
      socialLinks: band.socialLinks,
      merchUrl: band.merchUrl,
      donationGoal: band.donationGoal,
      status: BandStatus.pending,
      createdBy: band.createdBy,
      createdAt: DateTime.now(),
    );
    _bands.add(pending);
    return pending;
  }

  @override
  Future<Band> updateBand(Band band) async {
    for (var i = 0; i < _bands.length; i++) {
      if (_bands[i].id == band.id) {
        _bands[i] = band;
        return band;
      }
    }
    _bands.add(band);
    return band;
  }

  @override
  Future<List<BandMembership>> getMyMemberships(String userId) async {
    return [
      for (final band in _bands)
        if (band.createdBy == userId)
          BandMembership(band: band, role: MemberRole.owner),
    ];
  }

  @override
  Future<List<BandEvent>> getBandEvents(String bandId) async {
    return _events.where((e) => e.bandId == bandId).toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
  }

  @override
  Future<BandEvent> addBandEvent(BandEvent event) async {
    final created = BandEvent(
      id: event.id.isEmpty ? 'evt_${_events.length + 1}' : event.id,
      bandId: event.bandId,
      title: event.title,
      venue: event.venue,
      city: event.city,
      eventDate: event.eventDate,
      ticketUrl: event.ticketUrl,
      notes: event.notes,
    );
    _events.add(created);
    return created;
  }

  @override
  Future<void> deleteBandEvent(String eventId) async {
    _events.removeWhere((e) => e.id == eventId);
  }

  @override
  Future<List<BandPhoto>> getBandPhotos(String bandId) async {
    return _photos.where((p) => p.bandId == bandId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<BandPhoto> addBandPhoto(BandPhoto photo) async {
    final created = BandPhoto(
      id: photo.id.isEmpty ? 'photo_${_photos.length + 1}' : photo.id,
      bandId: photo.bandId,
      photoUrl: photo.photoUrl,
      caption: photo.caption,
      createdAt: photo.createdAt,
    );
    _photos.insert(0, created);
    return created;
  }

  @override
  Future<void> deleteBandPhoto(String photoId) async {
    _photos.removeWhere((p) => p.id == photoId);
  }

  @override
  Future<bool> isFollowingBand(String bandId) async {
    return _followedBands.contains(bandId);
  }

  @override
  Future<int> getFollowersCount(String bandId) async {
    return _followersCount[bandId] ?? 0;
  }

  @override
  Future<void> followBand(String bandId) async {
    if (_followedBands.add(bandId)) {
      _followersCount[bandId] = (_followersCount[bandId] ?? 0) + 1;
    }
  }

  @override
  Future<void> unfollowBand(String bandId) async {
    if (_followedBands.remove(bandId)) {
      final current = _followersCount[bandId] ?? 0;
      _followersCount[bandId] = current > 0 ? current - 1 : 0;
    }
  }

  void dispose() {
    _playEventsController.close();
  }
}
