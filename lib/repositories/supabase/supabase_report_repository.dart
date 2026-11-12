import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/report.dart';
import '../interfaces/report_repository.dart';

class SupabaseReportRepository implements ReportRepository {
  SupabaseReportRepository(this._client);

  final SupabaseClient _client;

  static const String _select = '*, bands(name), songs(title)';

  @override
  Future<Report> createReport({
    required String reason,
    String? bandId,
    String? songId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Necesitás iniciar sesión para enviar un reporte.');
    }
    final trimmed = reason.trim();
    if (trimmed.length < 5) {
      throw ArgumentError('El motivo debe tener al menos 5 caracteres.');
    }

    final payload = <String, dynamic>{'reporter_id': userId, 'reason': trimmed};
    if (bandId != null) payload['band_id'] = bandId;
    if (songId != null) payload['song_id'] = songId;

    final row = await _client
        .from('reports')
        .insert(payload)
        .select(_select)
        .single();

    return Report.fromJson(row);
  }

  @override
  Future<List<Report>> getReports({ReportStatus? status}) async {
    var query = _client.from('reports').select(_select);
    if (status != null) {
      query = query.eq('status', status.toDbString());
    }
    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => Report.fromJson(r)).toList();
  }

  @override
  Future<void> resolveReport(String reportId, {required bool dismiss}) async {
    final newStatus = dismiss ? 'dismissed' : 'resolved';
    await _client
        .from('reports')
        .update({'status': newStatus})
        .eq('id', reportId);
  }
}
