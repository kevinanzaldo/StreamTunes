import 'package:flutter/material.dart';

import '../models/band.dart';
import '../theme/app_theme.dart';
import '../view_models/band_dashboard_view_model.dart';
import '../widgets/player_bar.dart';
import '../widgets/repositories_scope.dart';
import '../widgets/session_scope.dart';
import 'band_public_view.dart';
import 'upload_view.dart';

/// Panel privado de gestión para miembros de una banda ("Mi banda").
///
/// Permite ver el estado de moderación, controlar el cupo de subida (X/20 temas),
/// calcular métricas avanzadas en segundo plano con Isolate (Criterio D3),
/// consultar donaciones recibidas y acceder rápidamente a la subida o al perfil público.
class BandDashboardView extends StatefulWidget {
  const BandDashboardView({super.key, required this.band, this.viewModel});

  final Band band;
  final BandDashboardViewModel? viewModel;

  @override
  State<BandDashboardView> createState() => _BandDashboardViewState();
}

class _BandDashboardViewState extends State<BandDashboardView> {
  late final BandDashboardViewModel _viewModel;
  bool _ownsViewModel = false;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
    } else {
      final repos = RepositoriesScope.of(context);
      _viewModel = BandDashboardViewModel(
        band: widget.band,
        songRepository: repos.songs,
        donationRepository: repos.donations,
        bandRepository: repos.bands,
      );
      _ownsViewModel = true;
      _viewModel.load();
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  Widget _buildStatusBanner(BandStatus status) {
    if (status == BandStatus.approved) return const SizedBox.shrink();

    final isPending = status == BandStatus.pending;
    final color = isPending ? Colors.amber : Colors.redAccent;
    final icon = isPending ? Icons.hourglass_top : Icons.warning_amber;
    final text = isPending
        ? 'Banda pendiente de aprobación: el Colectivo está revisando tu solicitud. '
              'Podrás subir canciones una vez aprobada.'
        : 'Banda suspendida: actualmente no es pública ni puede subir temas.';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    double? progress,
  }) {
    return Card(
      color: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryGreen, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection(BandDashboardViewModel vm) {
    return Card(
      color: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: AppTheme.primaryGreen, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Métricas en Segundo Plano (Isolate)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Cálculo de series pesadas (50.000 eventos de reproducción) ejecutado en un hilo separado sin congelar la pantalla.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            if (vm.isCalculatingStats)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.primaryGreen),
                      SizedBox(height: 10),
                      Text(
                        'Procesando en Isolate...',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else if (vm.metrics != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricItem(
                          'Reproducciones',
                          '${vm.metrics!.totalReproducciones}',
                        ),
                        _metricItem(
                          'Minutos totales',
                          '${vm.metrics!.totalMinutos}m',
                        ),
                      ],
                    ),
                    if (vm.metrics!.rankingOyentes.isNotEmpty) ...[
                      const Divider(color: Colors.white12, height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Top Oyentes:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final o in vm.metrics!.rankingOyentes.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                o.nombre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${o.minutos} min (${o.ubicacion})',
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: vm.calculateMetrics,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Recalcular'),
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.black,
                ),
                onPressed: vm.calculateMetrics,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text(
                  'Calcular estadísticas ahora',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            if (vm.statsError != null) ...[
              const SizedBox(height: 8),
              Text(
                vm.statsError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.primaryGreen,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, Band band) {
    final isApproved = band.isApproved;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproved
                  ? AppTheme.primaryGreen
                  : Colors.grey[800],
              foregroundColor: isApproved ? Colors.black : Colors.white38,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: isApproved
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UploadView()),
                    );
                  }
                : null,
            icon: const Icon(Icons.upload, size: 18),
            label: const Text(
              'Subir tema',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BandPublicView(band: band)),
              );
            },
            icon: const Icon(Icons.visibility, size: 18),
            label: const Text('Ver perfil público'),
          ),
        ),
      ],
    );
  }

  Widget _buildSongsList(BandDashboardViewModel vm) {
    if (vm.songs.isEmpty) {
      return Card(
        color: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No hay canciones subidas aún.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ),
      );
    }

    return Card(
      color: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: vm.songs.length,
        separatorBuilder: (_, _) =>
            const Divider(color: Colors.white10, height: 1),
        itemBuilder: (context, index) {
          final s = vm.songs[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.surface,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            title: Text(
              s.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${s.formattedDuration} · ${s.genre.isEmpty ? "Sin género" : s.genre}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            trailing: Text(
              '${s.playCount} plays',
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopListenersSection(BandDashboardViewModel vm) {
    if (vm.topListeners.isEmpty) {
      return Card(
        color: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.leaderboard_outlined, color: AppTheme.textMuted),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Aún no hay suficientes reproducciones para calcular el ranking de oyentes.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: vm.topListeners.length,
        separatorBuilder: (_, _) =>
            const Divider(color: Colors.white10, height: 1),
        itemBuilder: (context, index) {
          final listener = vm.topListeners[index];
          final name = (listener['display_name'] as String?) ?? 'Oyente';
          final minutes = (listener['minutes'] as num?)?.toInt() ?? 0;

          final medal = index == 0
              ? '🥇'
              : index == 1
              ? '🥈'
              : index == 2
              ? '🥉'
              : '#${index + 1}';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.surface,
              child: Text(medal, style: const TextStyle(fontSize: 14)),
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            trailing: Text(
              '$minutes min',
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.maybeOf(context);
    final activeBand = session?.activeBand ?? widget.band;

    return Scaffold(
      appBar: AppBar(title: Text('Panel: ${activeBand.name}')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            );
          }

          if (_viewModel.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _viewModel.error!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _viewModel.load,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final songProgress =
              (_viewModel.songCount / BandDashboardViewModel.maxSongs).clamp(
                0.0,
                1.0,
              );
          final totalPlays = _viewModel.songs.fold<int>(
            0,
            (acc, s) => acc + s.playCount,
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusBanner(activeBand.status),
                    // Tarjetas de resumen
                    if (isWide)
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              icon: Icons.music_note,
                              title: 'Cupo de temas',
                              value:
                                  '${_viewModel.songCount} / ${BandDashboardViewModel.maxSongs}',
                              subtitle: 'Límite máximo por banda',
                              progress: songProgress,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              icon: Icons.headset,
                              title: 'Reproducciones',
                              value: '$totalPlays',
                              subtitle: 'En todos tus temas',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              icon: Icons.favorite,
                              title: 'Fondo colectivo',
                              value:
                                  '\$${activeBand.donationsCollected.toInt()}',
                              subtitle:
                                  'Meta: \$${activeBand.donationGoal.toInt()}',
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildSummaryCard(
                            icon: Icons.music_note,
                            title: 'Cupo de temas',
                            value:
                                '${_viewModel.songCount} / ${BandDashboardViewModel.maxSongs}',
                            subtitle: 'Límite máximo por banda',
                            progress: songProgress,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.headset,
                                  title: 'Reproducciones',
                                  value: '$totalPlays',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.favorite,
                                  title: 'Fondo recaudado',
                                  value:
                                      '\$${activeBand.donationsCollected.toInt()}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    _buildQuickActions(context, activeBand),
                    const SizedBox(height: 20),
                    _buildMetricsSection(_viewModel),
                    const SizedBox(height: 20),
                    const Text(
                      'Top oyentes del mes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildTopListenersSection(_viewModel),
                    const SizedBox(height: 20),
                    const Text(
                      'Temas publicados',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSongsList(_viewModel),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomSheet: const PlayerBar(),
    );
  }
}
