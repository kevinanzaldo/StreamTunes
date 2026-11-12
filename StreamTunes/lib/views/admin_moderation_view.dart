import 'package:flutter/material.dart';

import '../models/band.dart';
import '../models/report.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/player_bar.dart';
import '../widgets/repositories_scope.dart';
import '../widgets/session_scope.dart';

/// Panel de moderación para administradores del Colectivo.
/// Permite aprobar o suspender bandas pendientes y gestionar reportes de contenido.
class AdminModerationView extends StatefulWidget {
  const AdminModerationView({super.key});

  @override
  State<AdminModerationView> createState() => _AdminModerationViewState();
}

class _AdminModerationViewState extends State<AdminModerationView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoading = true;
  String? _error;
  List<Band> _pendingBands = [];
  List<Report> _openReports = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repos = RepositoriesScope.of(context);
      final results = await Future.wait([
        repos.bands.getBandsByStatus(BandStatus.pending),
        repos.reports.getReports(status: ReportStatus.open),
      ]);
      if (mounted) {
        setState(() {
          _pendingBands = results[0] as List<Band>;
          _openReports = results[1] as List<Report>;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('AdminModerationView _loadData error: $e\n$st');
      if (mounted) {
        setState(() {
          _error = 'Error cargando datos de moderación.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleBandStatus(Band band, BandStatus newStatus) async {
    final repos = RepositoriesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repos.bands.updateBandStatus(band.id, newStatus);
      final msg = newStatus == BandStatus.approved
          ? 'Banda "${band.name}" aprobada con éxito.'
          : 'Banda "${band.name}" suspendida.';
      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: newStatus == BandStatus.approved
              ? AppTheme.primaryGreen
              : Colors.amber[800],
        ),
      );
      _loadData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al actualizar estado: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleResolveReport(Report report, bool dismiss) async {
    final repos = RepositoriesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repos.reports.resolveReport(report.id, dismiss: dismiss);
      final msg = dismiss
          ? 'Reporte desestimado.'
          : 'Reporte resuelto y medida aplicada.';
      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: dismiss
              ? AppTheme.surfaceElevated
              : AppTheme.primaryGreen,
        ),
      );
      _loadData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al procesar reporte: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.maybeOf(context);
    final isAdmin = session?.isAdmin ?? false;

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moderación')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Acceso restringido. Esta sección es exclusiva para administradores del Colectivo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderación del Colectivo'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.group),
              text: 'Bandas pendientes (${_pendingBands.length})',
            ),
            Tab(
              icon: const Icon(Icons.report_problem),
              text: 'Reportes abiertos (${_openReports.length})',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildPendingBandsList(), _buildReportsList()],
            ),
      bottomSheet: const PlayerBar(),
    );
  }

  Widget _buildPendingBandsList() {
    if (_pendingBands.isEmpty) {
      return const EmptyStateView(
        icon: Icons.check_circle_outline,
        title: 'No hay bandas pendientes de aprobación.',
        description: 'Todo el contenido nuevo se encuentra moderado.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _pendingBands.length,
      itemBuilder: (context, index) {
        final band = _pendingBands[index];
        return Card(
          color: AppTheme.surfaceElevated,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        band.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(40),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Pendiente',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${band.genre.isEmpty ? "Sin género" : band.genre} · ${band.location.isEmpty ? "Ubicación desconocida" : band.location}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
                if (band.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    band.bio,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      onPressed: () =>
                          _handleBandStatus(band, BandStatus.suspended),
                      child: const Text('Rechazar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () =>
                          _handleBandStatus(band, BandStatus.approved),
                      child: const Text('Aprobar banda'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportsList() {
    if (_openReports.isEmpty) {
      return const EmptyStateView(
        icon: Icons.done_all,
        title: 'No hay reportes abiertos',
        description: 'No se encontraron denuncias de contenido pendientes.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _openReports.length,
      itemBuilder: (context, index) {
        final rep = _openReports[index];
        final target = rep.songTitle != null
            ? 'Canción: ${rep.songTitle}'
            : rep.bandName != null
            ? 'Banda: ${rep.bandName}'
            : 'Contenido reportado';

        return Card(
          color: AppTheme.surfaceElevated,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.report, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        target,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '"${rep.reason}"',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _handleResolveReport(rep, true),
                      child: const Text(
                        'Desestimar',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => _handleResolveReport(rep, false),
                      child: const Text('Resolver reporte'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
