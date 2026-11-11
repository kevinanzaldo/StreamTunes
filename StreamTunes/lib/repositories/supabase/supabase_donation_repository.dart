import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_constants.dart';
import '../../models/donation.dart';
import '../interfaces/donation_repository.dart';

/// Implementación real sobre la tabla `donations`.
///
/// El tope por donación (`max_donation_ars`) y que la banda esté aprobada los
/// valida un trigger: llegan como `PostgrestException` con el mensaje en español.
/// La tabla no guarda el medio de pago, así que `paymentMethod` vuelve como 'N/D'.
class SupabaseDonationRepository implements DonationRepository {
  SupabaseDonationRepository(this._client);

  final SupabaseClient _client;

  static const String _select = '*, bands(name)';

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
    final rows = await _client
        .from('donations')
        .select(_select)
        .eq('band_id', bandId)
        .order('created_at', ascending: false);
    return rows.map(_fromRow).toList();
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
          return _fromRow(rows.first);
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
        })
        .select(_select)
        .single();
    return _fromRow(row);
  }

  Donation _fromRow(Map<String, dynamic> row) {
    final band = row['bands'] as Map<String, dynamic>?;
    return Donation(
      id: row['id'] as String,
      artistId: row['band_id'] as String,
      artistName: (band?['name'] as String?) ?? '',
      amount: (row['amount'] as num).toDouble(),
      currency: (row['currency'] as String?) ?? 'ARS',
      message: row['message'] as String?,
      paymentMethod: 'N/D',
      timestamp: DateTime.parse(row['created_at'] as String),
    );
  }
}
