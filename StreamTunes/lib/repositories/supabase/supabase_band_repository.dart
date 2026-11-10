import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/band.dart';
import '../../models/band_member.dart';
import '../../models/band_membership.dart';
import '../interfaces/band_repository.dart';
import '../interfaces/repository_failure.dart';

/// Implementación real sobre las tablas `bands` y `band_members`.
///
/// La visibilidad la decide RLS: el público solo ve bandas `approved`;
/// los miembros ven además las suyas.
class SupabaseBandRepository implements BandRepository {
  SupabaseBandRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Band>> getApprovedBands() async {
    final rows = await _client
        .from('bands')
        .select()
        .eq('status', 'approved')
        .order('name');
    return rows.map(Band.fromJson).toList();
  }

  @override
  Future<List<Band>> getBandsByStatus(BandStatus status) async {
    final rows = await _client
        .from('bands')
        .select()
        .eq('status', status.toDbString())
        .order('created_at', ascending: false);
    return rows.map(Band.fromJson).toList();
  }

  @override
  Future<void> updateBandStatus(String bandId, BandStatus status) async {
    await _client.rpc(
      'set_band_status',
      params: {'p_band': bandId, 'p_status': status.toDbString()},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getTopListeners(
    String bandId, {
    int days = 30,
  }) async {
    try {
      final res = await _client.rpc(
        'band_top_listeners',
        params: {'p_band': bandId, 'p_days': days},
      );
      if (res is List) {
        return res.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  @override
  Future<Band?> getBandById(String id) async {
    final row = await _client.from('bands').select().eq('id', id).maybeSingle();
    return row == null ? null : Band.fromJson(row);
  }

  /// `band.createdBy` debe ser el id del usuario logueado (lo exige RLS).
  /// La banda nace `pending`: no se puede elegir otro estado desde la app.
  @override
  Future<Band> createBand(Band band) async {
    try {
      final row = await _client
          .from('bands')
          .insert(band.toInsertJson())
          .select()
          .single();
      return Band.fromJson(row);
    } on PostgrestException catch (e) {
      // 23505 = `slug` repetido: ya hay una banda con ese nombre.
      if (e.code == '23505') {
        throw const RepositoryFailure('Ya existe una banda con ese nombre.');
      }
      rethrow;
    }
  }

  @override
  Future<List<BandMembership>> getMyMemberships(String userId) async {
    final rows = await _client
        .from('band_members')
        .select('role, bands(*)')
        .eq('user_id', userId);
    return [
      for (final row in rows)
        if (row['bands'] is Map<String, dynamic>)
          BandMembership(
            band: Band.fromJson(row['bands'] as Map<String, dynamic>),
            role: MemberRole.fromDb((row['role'] as String?) ?? 'member'),
          ),
    ];
  }
}
