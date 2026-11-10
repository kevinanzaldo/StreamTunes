import '../../models/report.dart';

abstract interface class ReportRepository {
  /// Registra un reporte sobre una banda o un tema musical.
  Future<Report> createReport({
    required String reason,
    String? bandId,
    String? songId,
  });

  /// Lista los reportes existentes, opcionalmente filtrados por estado.
  /// Solo accesible para moderadores y administradores.
  Future<List<Report>> getReports({ReportStatus? status});

  /// Resuelve un reporte:
  /// Si [dismiss] es true, se marca como desestimado ('dismissed').
  /// Si es false, se marca como resuelto ('resolved') aplicando la acción correctiva.
  Future<void> resolveReport(String reportId, {required bool dismiss});
}
