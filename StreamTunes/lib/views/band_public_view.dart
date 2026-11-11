import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../models/band.dart';
import '../models/donation.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../view_models/band_public_view_model.dart';
import '../widgets/player_bar.dart';
import '../widgets/repositories_scope.dart';
import '../widgets/session_scope.dart';
import '../widgets/song_tile.dart';
import 'band_dashboard_view.dart';

/// Perfil público de una banda accesible para cualquier visitante u oyente.
///
/// Muestra información de la banda (portada, bio, redes), meta de financiamiento,
/// temas más escuchados, opción para donar y reportar. En pantallas anchas
/// (≥600 px) se adapta a 2 columnas.
class BandPublicView extends StatefulWidget {
  const BandPublicView({super.key, required this.band, this.viewModel});

  final Band band;
  final BandPublicViewModel? viewModel;

  @override
  State<BandPublicView> createState() => _BandPublicViewState();
}

class _BandPublicViewState extends State<BandPublicView> {
  late final BandPublicViewModel _viewModel;
  bool _ownsViewModel = false;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
    } else {
      final repos = RepositoriesScope.of(context);
      _viewModel = BandPublicViewModel(
        band: widget.band,
        songRepository: repos.songs,
        donationRepository: repos.donations,
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

  void _mostrarDialogoDonar() {
    final controller = TextEditingController(text: '¡Gran música, sigan así!');
    final amounts = _viewModel.donationAmounts;
    final maxLabel = formatArsAmount(_viewModel.maxDonationArs);
    double montoSeleccionado = amounts.contains(1000.0)
        ? 1000.0
        : amounts.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceElevated,
            title: Text(
              'Apoyar a ${widget.band.name}',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_viewModel.spendCapActive)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withAlpha(100)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Estamos con alta demanda – topes de gasto activos (máx $maxLabel).',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withAlpha(100)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Control de gasto: máximo $maxLabel por donación para cuidar la comunidad.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Text(
                    'Seleccionar monto (ARS):',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: amounts.map((monto) {
                      final isSelected = montoSeleccionado == monto;
                      return ChoiceChip(
                        label: Text(formatArsAmount(monto)),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryGreen,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        backgroundColor: AppTheme.surface,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => montoSeleccionado = monto);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Mensaje de apoyo (opcional)',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  final ok = await _viewModel.donate(
                    amount: montoSeleccionado,
                    message: controller.text.trim(),
                  );
                  if (ok) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          '¡Gracias por apoyar a ${widget.band.name}!',
                        ),
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo registrar la donación.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Confirmar aporte',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarDialogoReportar() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: Text(
          'Reportar a ${widget.band.name}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indica el motivo del reporte (ej. contenido inapropiado o violación de derechos):',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Detalle del motivo...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'El motivo debe tener al menos 5 caracteres.',
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                final repos = RepositoriesScope.of(context);
                await repos.reports.createReport(
                  reason: reason,
                  bandId: widget.band.id,
                );
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Reporte enviado al Colectivo para revisión.',
                    ),
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                );
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('No se pudo enviar el reporte.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Enviar reporte'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, bool isMember) {
    final band = widget.band;
    final progress = band.donationGoal > 0
        ? (band.donationsCollected / band.donationGoal).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      color: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: band.coverUrl != null && band.coverUrl!.isNotEmpty
                      ? Image.network(
                          band.coverUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: AppTheme.primaryGreen
                                    .withAlpha(40),
                                child: const Icon(
                                  Icons.groups,
                                  size: 36,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                        )
                      : CircleAvatar(
                          radius: 36,
                          backgroundColor: AppTheme.primaryGreen.withAlpha(40),
                          child: const Icon(
                            Icons.groups,
                            size: 36,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        band.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (band.genre.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                band.genre,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (band.location.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.place,
                                  size: 14,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    band.location,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (band.bio.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                band.bio,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            if (band.socialLinks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: band.socialLinks.entries.map((entry) {
                  return Chip(
                    backgroundColor: AppTheme.surface,
                    label: Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const Divider(color: Colors.white12, height: 28),
            // Meta de financiamiento
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Fondo colectivo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '\$${band.donationsCollected.toInt()} / \$${band.donationGoal.toInt()}',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _mostrarDialogoDonar,
                    icon: const Icon(Icons.favorite, size: 18),
                    label: const Text(
                      'Apoyar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  onPressed: _mostrarDialogoReportar,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Reportar'),
                ),
              ],
            ),
            if (isMember) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withAlpha(80),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_user,
                          color: AppTheme.primaryGreen,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Eres miembro de esta banda',
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BandDashboardView(band: widget.band),
                          ),
                        );
                      },
                      icon: const Icon(Icons.dashboard, size: 16),
                      label: const Text(
                        'Panel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _buildDonationsWall(_viewModel.recentDonations),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveAlertBanner() {
    final alert = _viewModel.latestDonationAlert;
    if (alert == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryGreen),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration, color: AppTheme.primaryGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '¡Aporte en vivo de ${alert.formattedAmount}! ${alert.message != null ? "\"${alert.message}\"" : ""}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.white60),
            onPressed: _viewModel.dismissAlert,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationsWall(List<Donation> donations) {
    if (donations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(
              Icons.volunteer_activism,
              size: 16,
              color: AppTheme.primaryGreen,
            ),
            SizedBox(width: 6),
            Text(
              'Muro de apoyo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: donations.take(3).length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final don = donations[i];
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        don.donorName ?? 'Oyente solidario',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        don.formattedAmount,
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (don.message != null && don.message!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '"${don.message}"',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSongsSection(List<Song> songs, bool isLoading, String? error) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _viewModel.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (songs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Esta banda todavía no subió temas.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Temas más escuchados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: songs.length,
          separatorBuilder: (_, _) =>
              const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, index) {
            final song = songs[index];
            return SongTile(song: song);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.maybeOf(context);
    final isMember = session?.isMemberOf(widget.band.id) ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(widget.band.name)),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;

              if (isWide) {
                // Layout 2 columnas adaptativo en pantallas anchas
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 340,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildLiveAlertBanner(),
                            _buildInfoCard(context, isMember),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(color: Colors.white12, width: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        child: _buildSongsSection(
                          _viewModel.songs,
                          _viewModel.isLoading,
                          _viewModel.error,
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Layout móvil / columna única
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLiveAlertBanner(),
                    _buildInfoCard(context, isMember),
                    const SizedBox(height: 20),
                    _buildSongsSection(
                      _viewModel.songs,
                      _viewModel.isLoading,
                      _viewModel.error,
                    ),
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
