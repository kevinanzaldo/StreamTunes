import '../../models/donation.dart';

/// Acceso a las donaciones del usuario. Implementaciones:
/// `FakeDonationRepository` (tests/demo) y `SupabaseDonationRepository`.
abstract interface class DonationRepository {
  /// Donaciones hechas por el usuario actual, de la más nueva a la más vieja.
  /// Sin sesión devuelve una lista vacía.
  Future<List<Donation>> getMyDonations();

  /// Donaciones recibidas por una banda específica.
  Future<List<Donation>> getBandDonations(String bandId);

  /// Emite en tiempo real las donaciones recibidas por una banda específica.
  Stream<Donation> watchBandDonations(String bandId);

  /// Consulta si el modo de "alta demanda / topes de gasto activos" está habilitado.
  Future<bool> isSpendCapActive();

  /// Registra una donación a una banda (`Donation.artistId` = id de la banda).
  /// La base valida el tope por donación y que la banda esté aprobada;
  /// esos errores llegan como excepción. Lanza si no hay sesión.
  Future<Donation> addDonation(Donation donation);
}
