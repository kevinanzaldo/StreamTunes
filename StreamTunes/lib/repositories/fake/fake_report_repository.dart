import '../../models/report.dart';
import '../interfaces/report_repository.dart';

class FakeReportRepository implements ReportRepository {
  FakeReportRepository() {
    // Reportes demo iniciales
    _reports.addAll([
      Report(
        id: 'rep_demo_1',
        reporterId: 'caro_id',
        bandId: 'artist_1',
        bandName: 'Los Subterráneos',
        reason: 'Posible infracción de derechos en versión acústica',
        status: ReportStatus.open,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Report(
        id: 'rep_demo_2',
        reporterId: 'beto_id',
        songId: 'song_3',
        songTitle: 'Niebla en la Ciudad',
        reason: 'Audio con volumen saturado y ruido de línea',
        status: ReportStatus.open,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ]);
  }

  final List<Report> _reports = [];

  @override
  Future<Report> createReport({
    required String reason,
    String? bandId,
    String? songId,
  }) async {
    final report = Report(
      id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      reporterId: 'user_actual',
      bandId: bandId,
      songId: songId,
      reason: reason,
      status: ReportStatus.open,
      createdAt: DateTime.now(),
    );
    _reports.insert(0, report);
    return report;
  }

  @override
  Future<List<Report>> getReports({ReportStatus? status}) async {
    if (status == null) {
      return List<Report>.unmodifiable(_reports);
    }
    return List<Report>.unmodifiable(_reports.where((r) => r.status == status));
  }

  @override
  Future<void> resolveReport(String reportId, {required bool dismiss}) async {
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index != -1) {
      final old = _reports[index];
      _reports[index] = Report(
        id: old.id,
        reporterId: old.reporterId,
        bandId: old.bandId,
        songId: old.songId,
        reason: old.reason,
        status: dismiss ? ReportStatus.dismissed : ReportStatus.resolved,
        createdAt: old.createdAt,
        bandName: old.bandName,
        songTitle: old.songTitle,
      );
    }
  }
}
