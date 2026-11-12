import 'band.dart';
import 'band_member.dart';

/// Una banda junto con el rol que tiene en ella la persona logueada.
/// Incluye bandas `pending` y `suspended`: el miembro siempre ve las suyas.
class BandMembership {
  const BandMembership({required this.band, required this.role});

  final Band band;
  final MemberRole role;

  bool get isOwner => role == MemberRole.owner;
}
