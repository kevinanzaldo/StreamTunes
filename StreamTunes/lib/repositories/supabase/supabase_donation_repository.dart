import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_constants.dart';
import '../../models/donation.dart';
import '../interfaces/donation_repository.dart';

/// Implementación real sobre la tabla `donations`.
///
/// El tope por donación (`max_donation_ars`) y que la banda esté aprobada los
/// valida un trigger: llegan como `PostgrestException` con el mensaje en español.
class SupabaseDonationRepository implements DonationRepository {
  SupabaseDonationRepository(this._client);

  final SupabaseClient _client;

  static const String _select =
      '*, bands(name), profiles:donor_id(display_name)';

  @override
  Future<List<Donation>> getMyDonations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('donations')
        .select(_select)
        .eq('donor_id', userId)
        .order('created_at', ascending: false);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Donation>> getBandDonations(String bandId) async {
    try {
      final rows = await _client
          .from('donations')
          .select(_select)
          .eq('band_id', bandId)
          .eq('status', 'approved')
          .order('created_at', ascending: false);
      return rows.map(_fromRow).where((d) => d.isApproved).toList();
    } on PostgrestException catch (e) {
      if (e.code == '42703' || e.message.toLowerCase().contains('status')) {
        final fallbackRows = await _client
            .from('donations')
            .select(_select)
            .eq('band_id', bandId)
            .order('created_at', ascending: false);
        return fallbackRows.map(_fromRow).toList();
      }
      rethrow;
    }
  }

  @override
  Stream<Donation> watchBandDonations(String bandId) {
    return _client
        .from('donations')
        .stream(primaryKey: ['id'])
        .eq('band_id', bandId)
        .order('created_at', ascending: false)
        .map((rows) {
          if (rows.isEmpty) return null;
          final donation = _fromRow(rows.first);
          return donation.isApproved ? donation : null;
        })
        .where((d) => d != null)
        .cast<Donation>();
  }

  @override
  Future<bool> isSpendCapActive() async {
    try {
      final res = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'spend_cap_active')
          .maybeSingle();
      if (res != null) {
        return (res['value'] as num?) == 1;
      }
    } catch (e) {
      debugPrint('Error consultando spend_cap_active: $e');
    }
    return false;
  }

  @override
  Future<double> getMaxDonationArs() async {
    try {
      final res = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'max_donation_ars')
          .maybeSingle();
      final val = (res?['value'] as num?)?.toDouble();
      if (val != null && val > 0) return val;
    } catch (e) {
      debugPrint('Error consultando max_donation_ars: $e');
    }
    return kMaxDonationArs;
  }

  @override
  Future<Donation> addDonation(Donation donation) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Necesitás iniciar sesión para donar.');
    }
    final message = donation.message?.trim();
    final row = await _client
        .from('donations')
        .insert({
          'band_id': donation.artistId,
          'donor_id': userId,
          'amount': donation.amount,
          'currency': donation.currency,
          'message': (message == null || message.isEmpty) ? null : message,
          'is_public': donation.isPublic,
          'status': donation.status.dbValue,
        })
        .select(_select)
        .single();
    return _fromRow(row);
  }

  Donation _fromRow(Map<String, dynamic> row) {
    final band = row['bands'] as Map<String, dynamic>?;
    final profile = row['profiles'] as Map<String, dynamic>?;
    final isPublic = (row['is_public'] as bool?) ?? true;
    final donorDisplay = isPublic
        ? (profile?['display_name'] as String?) ?? 'Fan'
        : 'Donante anónimo';

    return Donation(
      id: row['id'] as String,
      artistId: row['band_id'] as String,
      artistName: (band?['name'] as String?) ?? '',
      amount: (row['amount'] as num).toDouble(),
      currency: (row['currency'] as String?) ?? 'ARS',
      message: row['message'] as String?,
      paymentMethod: 'Pasarela externa',
      timestamp: DateTime.parse(row['created_at'] as String),
      donorName: donorDisplay,
      isPublic: isPublic,
      status: DonationStatus.fromDb(row['status'] as String?),
    );
  }
}
