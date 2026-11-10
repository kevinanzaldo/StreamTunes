import '../../models/band.dart';
import '../../models/band_membership.dart';

/// Acceso a los perfiles públicos de banda. Implementaciones: `FakeBandRepository`
/// (tests/demo) y `SupabaseBandRepository`.
abstract interface class BandRepository {
  /// Bandas visibles para el público (estado `approved`).
  Future<List<Band>> getApprovedBands();

  /// Obtiene bandas filtradas por estado (por ejemplo `pending` para moderación).
  Future<List<Band>> getBandsByStatus(BandStatus status);

  /// Actualiza el estado de una banda (solo moderadores/admin).
  Future<void> updateBandStatus(String bandId, BandStatus status);

  /// Ranking de oyentes con más minutos escuchados en los últimos [days] días.
  Future<List<Map<String, dynamic>>> getTopListeners(
    String bandId, {
    int days = 30,
  });

  Future<Band?> getBandById(String id);

  /// Crea una banda. Nace en estado `pending` hasta que un moderador la apruebe.
  /// Lanza `RepositoryFailure` si ya existe una con ese nombre (mismo `slug`).
  Future<Band> createBand(Band band);

  /// Bandas de las que [userId] es miembro (cualquier estado), con su rol.
  Future<List<BandMembership>> getMyMemberships(String userId);
}
