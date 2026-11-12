import '../../models/band.dart';
import '../../models/band_event.dart';
import '../../models/band_membership.dart';
import '../../models/band_photo.dart';
import '../../models/metricas_artista.dart';

/// Acceso a los perfiles públicos de banda, estadísticas del servidor,
/// agenda de recitales, galería de fotos y seguimiento por QR.
abstract interface class BandRepository {
  /// Bandas visibles para el público (estado `approved`).
  Future<List<Band>> getApprovedBands();

  /// Obtiene bandas filtradas por estado (por ejemplo `pending` para moderación).
  Future<List<Band>> getBandsByStatus(BandStatus status);

  /// Actualiza el estado de una banda (solo moderadores/admin).
  Future<void> updateBandStatus(String bandId, BandStatus status);

  /// Estadísticas globales agregadas en el servidor (Postgres RPC `band_aggregated_stats`).
  /// Si no hay reproducciones devuelve todo en 0 limpiamente.
  Future<MetricasArtista> getBandAggregatedStats(String bandId);

  /// Ranking Top 10 de fans en los últimos [days] días (Postgres RPC `band_top_fans`).
  /// Solo expone nombre/avatar si el fan activó `is_public_profile`; si no, devuelve "Fan anónimo".
  Future<List<OyenteTop>> getBandTopFans(String bandId, {int days = 30});

  /// Stream Realtime de nuevos eventos de reproducción de la banda para refrescar el ranking en vivo.
  Stream<void> watchBandPlayEvents(String bandId);

  Future<Band?> getBandById(String id);

  Future<Band?> getBandBySlug(String slug);

  /// Crea una banda. Nace en estado `pending` hasta que un moderador la apruebe.
  /// Lanza `RepositoryFailure` si ya existe una con ese nombre (mismo `slug`).
  Future<Band> createBand(Band band);

  /// Actualiza los datos editables, merch y foto de portada de una banda.
  Future<Band> updateBand(Band band);

  /// Bandas de las que [userId] es miembro (cualquier estado), con su rol.
  Future<List<BandMembership>> getMyMemberships(String userId);

  // --- Agenda de fechas (`band_events`) ---
  Future<List<BandEvent>> getBandEvents(String bandId);
  Future<BandEvent> addBandEvent(BandEvent event);
  Future<void> deleteBandEvent(String eventId);

  // --- Galería de fotos (`band_photos`) ---
  Future<List<BandPhoto>> getBandPhotos(String bandId);
  Future<BandPhoto> addBandPhoto(BandPhoto photo);
  Future<void> deleteBandPhoto(String photoId);

  // --- Seguimiento de bandas (`band_follows`) ---
  Future<bool> isFollowingBand(String bandId);
  Future<int> getFollowersCount(String bandId);
  Future<void> followBand(String bandId);
  Future<void> unfollowBand(String bandId);
}
