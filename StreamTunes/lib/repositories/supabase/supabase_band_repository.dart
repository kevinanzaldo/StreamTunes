import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/band.dart';
import '../../models/band_event.dart';
import '../../models/band_member.dart';
import '../../models/band_membership.dart';
import '../../models/band_photo.dart';
import '../../models/metricas_artista.dart';
import '../interfaces/band_repository.dart';
import '../interfaces/repository_failure.dart';

/// Implementación real sobre `bands`, `band_members`, `band_events`,
/// `band_photos`, `band_follows` y RPCs de estadísticas en Postgres.
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
  Future<MetricasArtista> getBandAggregatedStats(String bandId) async {
    try {
      final res = await _client.rpc(
        'band_aggregated_stats',
        params: {'p_band': bandId},
      );
      final topFans = await getBandTopFans(bandId);
      if (res is Map<String, dynamic>) {
        final totalPlays = (res['total_plays'] as num?)?.toInt() ?? 0;
        final totalMinutes = (res['total_minutes'] as num?)?.toInt() ?? 0;
        final rawSongs = res['top_songs'] as List? ?? const [];
        final rawDays = res['daily_stats'] as List? ?? const [];

        final topTemas = [
          for (final item in rawSongs.whereType<Map<String, dynamic>>())
            TemaMetrica(
              songId: (item['song_id'] as String?) ?? '',
              titulo: (item['title'] as String?) ?? '',
              reproducciones: (item['plays'] as num?)?.toInt() ?? 0,
              minutos: (item['minutes'] as num?)?.toInt() ?? 0,
            ),
        ];

        final dailyStats = [
          for (final item in rawDays.whereType<Map<String, dynamic>>())
            DiaMetrica(
              fecha: (item['day'] as String?) ?? '',
              reproducciones: (item['plays'] as num?)?.toInt() ?? 0,
              minutos: (item['minutes'] as num?)?.toInt() ?? 0,
            ),
        ];

        return MetricasArtista(
          totalMinutos: totalMinutes,
          totalReproducciones: totalPlays,
          rankingOyentes: topFans,
          topTemas: topTemas,
          reproduccionesPorDia: dailyStats,
          totalEventosReales: totalPlays,
        );
      }
    } catch (e) {
      debugPrint('Error RPC band_aggregated_stats: $e');
    }
    return MetricasArtista.empty;
  }

  @override
  Future<List<OyenteTop>> getBandTopFans(String bandId, {int days = 30}) async {
    try {
      final res = await _client.rpc(
        'band_top_fans',
        params: {'p_band': bandId, 'p_days': days},
      );
      if (res is List) {
        return res.whereType<Map<String, dynamic>>().map((row) {
          final isPublic = (row['is_public'] as bool?) ?? false;
          final rawName = (row['display_name'] as String?)?.trim() ?? '';
          return OyenteTop(
            nombre: isPublic && rawName.isNotEmpty ? rawName : 'Fan anónimo',
            minutos: (row['minutes'] as num?)?.toInt() ?? 0,
            avatarUrl: isPublic ? row['avatar_url'] as String? : null,
            isPublic: isPublic,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error RPC band_top_fans: $e');
    }
    return const [];
  }

  @override
  Stream<void> watchBandPlayEvents(String bandId) {
    return _client
        .from('play_events')
        .stream(primaryKey: ['id'])
        .eq('band_id', bandId)
        .map((_) {});
  }

  @override
  Future<Band?> getBandById(String id) async {
    final row = await _client.from('bands').select().eq('id', id).maybeSingle();
    return row == null ? null : Band.fromJson(row);
  }

  @override
  Future<Band?> getBandBySlug(String slug) async {
    final row = await _client
        .from('bands')
        .select()
        .eq('slug', slug)
        .maybeSingle();
    return row == null ? null : Band.fromJson(row);
  }

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
      if (e.code == '23505') {
        throw const RepositoryFailure('Ya existe una banda con ese nombre.');
      }
      rethrow;
    }
  }

  @override
  Future<Band> updateBand(Band band) async {
    try {
      final row = await _client
          .from('bands')
          .update(band.toUpdateJson())
          .eq('id', band.id)
          .select()
          .single();
      return Band.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const RepositoryFailure('Ya existe una banda con ese nombre.');
      }
      throw RepositoryFailure('No se pudo actualizar la banda: ${e.message}');
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

  @override
  Future<List<BandEvent>> getBandEvents(String bandId) async {
    try {
      final rows = await _client
          .from('band_events')
          .select()
          .eq('band_id', bandId)
          .order('event_date', ascending: true);
      return rows.map(BandEvent.fromJson).toList();
    } catch (e) {
      debugPrint('Error cargando band_events: $e');
      return const [];
    }
  }

  @override
  Future<BandEvent> addBandEvent(BandEvent event) async {
    try {
      final row = await _client
          .from('band_events')
          .insert(event.toInsertJson())
          .select()
          .single();
      return BandEvent.fromJson(row);
    } on PostgrestException catch (e) {
      throw RepositoryFailure('No se pudo guardar la fecha: ${e.message}');
    }
  }

  @override
  Future<void> deleteBandEvent(String eventId) async {
    await _client.from('band_events').delete().eq('id', eventId);
  }

  @override
  Future<List<BandPhoto>> getBandPhotos(String bandId) async {
    try {
      final rows = await _client
          .from('band_photos')
          .select()
          .eq('band_id', bandId)
          .order('created_at', ascending: false);
      return rows.map(BandPhoto.fromJson).toList();
    } catch (e) {
      debugPrint('Error cargando band_photos: $e');
      return const [];
    }
  }

  @override
  Future<BandPhoto> addBandPhoto(BandPhoto photo) async {
    try {
      final row = await _client
          .from('band_photos')
          .insert(photo.toInsertJson())
          .select()
          .single();
      return BandPhoto.fromJson(row);
    } on PostgrestException catch (e) {
      throw RepositoryFailure('No se pudo guardar la foto: ${e.message}');
    }
  }

  @override
  Future<void> deleteBandPhoto(String photoId) async {
    await _client.from('band_photos').delete().eq('id', photoId);
  }

  @override
  Future<bool> isFollowingBand(String bandId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final row = await _client
          .from('band_follows')
          .select('band_id')
          .eq('band_id', bandId)
          .eq('user_id', userId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> getFollowersCount(String bandId) async {
    try {
      final rows = await _client
          .from('band_follows')
          .select('user_id')
          .eq('band_id', bandId);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> followBand(String bandId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const RepositoryFailure('No hay sesión activa para seguir.');
    }
    await _client.from('band_follows').upsert({
      'band_id': bandId,
      'user_id': userId,
    });
  }

  @override
  Future<void> unfollowBand(String bandId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('band_follows')
        .delete()
        .eq('band_id', bandId)
        .eq('user_id', userId);
  }
}
