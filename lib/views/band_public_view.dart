import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_constants.dart';
import '../models/band.dart';
import '../models/donation.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../view_models/band_public_view_model.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/player_bar.dart';
import '../widgets/repositories_scope.dart';
import '../widgets/session_scope.dart';
import '../widgets/song_tile.dart';
import 'band_dashboard_view.dart';

/// Perfil público de una banda accesible para cualquier visitante u oyente.
///
/// Muestra información de la banda, seguir rápido por QR (sin registro),
/// meta de financiamiento, temas, Top 10 fans en vivo, fotos de shows,
/// agenda de fechas, enlace a merch y muro de donaciones. En pantalla grande
/// (≥800 px) se adapta automáticamente a 2 columnas con `LayoutBuilder`.
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
        bandRepository: repos.bands,
      );
      _ownsViewModel = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _viewModel.load();
      });
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  Future<void> _handleFollowPressed() async {
    final session = SessionScope.maybeRead(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await _viewModel.toggleFollow(
      ensureAnonymousSession: session == null
          ? null
          : () => session.signInAnonymously(),
    );

    if (!mounted) return;
    if (result.following) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.queuedOffline
                ? 'Seguimiento guardado en el celu: se sincroniza cuando vuelva la señal.'
                : '¡Ya estás siguiendo a ${widget.band.name}!',
          ),
          backgroundColor: result.queuedOffline
              ? Colors.orangeAccent
              : AppTheme.primaryGreen,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('Dejaste de seguir a ${widget.band.name}.')),
      );
    }
  }

  void _mostrarDialogoDonar() {
    final controller = TextEditingController(text: '¡Gran música, sigan así!');
    final amounts = _viewModel.donationAmounts;
    final maxLabel = formatArsAmount(_viewModel.maxDonationArs);
    double montoSeleccionado = amounts.contains(1000.0)
        ? 1000.0
        : amounts.first;
    bool donarAnonimo = false;

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
                      key: const ValueKey('spend_cap_banner'),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withAlpha(110)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.network_check,
                            color: Colors.orangeAccent,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Modo de cuidado de ancho de banda activo por alta demanda del servidor.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    key: const ValueKey('max_donation_banner'),
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
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Límite máximo por transacción para seguridad del donante: $maxLabel ARS.',
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
                    'Elegí el monto (ARS):',
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
                      labelText: 'Mensaje para el muro (opcional)',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const ValueKey('donate_anonymous_switch'),
                    value: donarAnonimo,
                    onChanged: (val) =>
                        setDialogState(() => donarAnonimo = val),
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: AppTheme.primaryGreen,
                    title: const Text(
                      'Donar de forma anónima',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'No muestra tu nombre en el muro público.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ),
                  const Text(
                    'Los aportes se procesan mediante pasarela de pago externa (pueden aplicar comisiones de cobro). Los pedidos de reembolso se gestionan de forma manual con la banda.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      height: 1.3,
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
                    isPublic: !donarAnonimo,
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
              'Indicá el motivo del reporte (ej. contenido inapropiado o violación de derechos):',
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
    final progress = band.donationProgress;

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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('follow_band_button'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _viewModel.isFollowing
                          ? AppTheme.primaryGreen.withAlpha(35)
                          : Colors.transparent,
                      foregroundColor: _viewModel.isFollowing
                          ? AppTheme.primaryGreen
                          : Colors.white,
                      side: BorderSide(
                        color: _viewModel.isFollowing
                            ? AppTheme.primaryGreen
                            : Colors.white24,
                      ),
                    ),
                    onPressed: _handleFollowPressed,
                    icon: Icon(
                      _viewModel.isFollowing ? Icons.check : Icons.person_add,
                      size: 18,
                    ),
                    label: Text(
                      _viewModel.isFollowing
                          ? 'Siguiendo (${_viewModel.followersCount})'
                          : 'Seguir (${_viewModel.followersCount})',
                    ),
                  ),
                ),
              ],
            ),
            if (band.bio.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                band.bio,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            if (band.merchUrl != null && band.merchUrl!.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('band_merch_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      ClipboardData(text: band.merchUrl!),
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Link de merch copiado: ${band.merchUrl}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  label: const Text('Tienda de merch (remeras y vinilos)'),
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
                          'Sos miembro de esta banda',
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

  Widget _buildSpendCapBanner() {
    if (!_viewModel.spendCapActive) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orangeAccent),
      ),
      child: const Row(
        children: [
          Icon(Icons.speed, color: Colors.orangeAccent, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo de cuidado de ancho de banda activo por alta demanda del servidor.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
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
        if (donations.isEmpty)
          const Text(
            'Sé el primero en apoyar a esta banda en el muro.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: donations.take(5).length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final don = donations[i];
              final donorLabel = don.isPublic
                  ? (don.donorName ?? 'Fan')
                  : 'Donante anónimo';
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
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
                          donorLabel,
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

  Widget _buildTopFansSection() {
    final fans = _viewModel.topFans;
    if (fans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Top 10 fans en vivo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fans.length,
            separatorBuilder: (_, _) =>
                const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final fan = fans[index];
              final hasAvatar =
                  fan.isPublic &&
                  fan.avatarUrl != null &&
                  fan.avatarUrl!.isNotEmpty;
              return ListTile(
                dense: true,
                leading: hasAvatar
                    ? CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(fan.avatarUrl!),
                      )
                    : CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.surface,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                title: Text(
                  fan.nombre,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                trailing: Text(
                  '${fan.minutos} min',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventsSection() {
    final events = _viewModel.events;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Próximas fechas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const EmptyStateView(
            icon: Icons.event_busy,
            title: 'Sin fechas confirmadas',
            description: 'La banda todavía no programó próximos recitales.',
            compact: true,
          )
        else
          Card(
            color: AppTheme.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final ev = events[index];
                return ListTile(
                  leading: const Icon(
                    Icons.event,
                    color: AppTheme.primaryGreen,
                  ),
                  title: Text(
                    ev.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${ev.formattedDate} · ${ev.venue}${ev.city.isNotEmpty ? " (${ev.city})" : ""}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPhotosGallery() {
    final photos = _viewModel.photos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Fotos de shows',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        if (photos.isEmpty)
          const EmptyStateView(
            icon: Icons.photo_library_outlined,
            title: 'Sin fotos todavía',
            description:
                'Pronto vas a ver fotos de sus presentaciones en vivo.',
            compact: true,
          )
        else
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final photo = photos[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        photo.photoUrl,
                        width: 160,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 160,
                          height: 110,
                          color: Colors.white10,
                          child: const Icon(Icons.image, color: Colors.white38),
                        ),
                      ),
                    ),
                    if (photo.caption != null && photo.caption!.isNotEmpty)
                      SizedBox(
                        width: 160,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            photo.caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
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
              final isWide = constraints.maxWidth >= 800;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 360,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        child: Column(
                          children: [
                            _buildSpendCapBanner(),
                            _buildLiveAlertBanner(),
                            _buildInfoCard(context, isMember),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(color: Colors.white12, width: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSongsSection(
                              _viewModel.songs,
                              _viewModel.isLoading,
                              _viewModel.error,
                            ),
                            _buildPhotosGallery(),
                            _buildEventsSection(),
                            _buildTopFansSection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSpendCapBanner(),
                    _buildLiveAlertBanner(),
                    _buildInfoCard(context, isMember),
                    const SizedBox(height: 20),
                    _buildSongsSection(
                      _viewModel.songs,
                      _viewModel.isLoading,
                      _viewModel.error,
                    ),
                    _buildPhotosGallery(),
                    _buildEventsSection(),
                    _buildTopFansSection(),
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
