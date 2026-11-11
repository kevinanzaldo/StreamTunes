import 'package:flutter/material.dart';

import '../models/band.dart';
import '../models/song.dart';
import '../services/dispositivo_capacidades.dart';
import '../theme/app_theme.dart';
import '../view_models/band_dashboard_view_model.dart';
import '../widgets/player_bar.dart';
import '../widgets/repositories_scope.dart';
import '../widgets/session_scope.dart';
import 'band_public_view.dart';
import 'upload_view.dart';

/// Panel privado de gestión para miembros de una banda ("Mi banda").
///
/// Permite ver el estado de moderación, controlar el cupo de subida (X/$kMaxSongsPerBand temas),
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
        storageRepository: repos.storage,
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
              'Simulación de carga: generación y agregación de 50.000 eventos dentro del Isolate sin congelar la UI, junto al ranking real de play_events.',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (vm.metrics!.esSimulacion) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.amberAccent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'Datos de demostración (benchmark Isolate 50k)',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
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
                        _metricItem(
                          'Días agregados',
                          '${vm.metrics!.reproduccionesPorDia.length}',
                        ),
                      ],
                    ),
                    if (vm.metrics!.topTemas.isNotEmpty) ...[
                      const Divider(color: Colors.white12, height: 20),
                      const Text(
                        'Top temas agregados (Isolate):',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final tema in vm.metrics!.topTemas.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  tema.titulo,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${tema.reproducciones} plays (${tema.minutos}m)',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const Divider(color: Colors.white12, height: 20),
                    const Text(
                      'Top Oyentes (play_events reales):',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (vm.metrics!.rankingOyentes.isEmpty)
                      const Text(
                        'Sin eventos de reproducción reales registrados todavía.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      )
                    else
                      for (final o in vm.metrics!.rankingOyentes.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  o.nombre,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                o.ubicacion.isNotEmpty
                                    ? '${o.minutos} min (${o.ubicacion})'
                                    : '${o.minutos} min',
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
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

    return Column(
      children: [
        Row(
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
                    MaterialPageRoute(
                      builder: (_) => BandPublicView(band: band),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('Ver perfil público'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('edit_band_button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryGreen,
              side: const BorderSide(color: AppTheme.primaryGreen),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => _showEditBandDialog(context, band),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text(
              'Editar datos y foto de la banda',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditBandDialog(BuildContext context, Band band) async {
    final nameController = TextEditingController(text: band.name);
    final genreController = TextEditingController(text: band.genre);
    final bioController = TextEditingController(text: band.bio);
    final locationController = TextEditingController(text: band.location);
    final goalController = TextEditingController(
      text: band.donationGoal > 0 ? band.donationGoal.toInt().toString() : '',
    );
    SelectedImageFile? selectedImage;
    bool saving = false;
    String? localError;

    final repos = RepositoriesScope.of(context);
    final session = SessionScope.maybeOf(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.edit, color: AppTheme.primaryGreen),
                  SizedBox(width: 10),
                  Text(
                    'Editar datos y foto',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (localError != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            localError!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      // Portada de la banda
                      const Text(
                        'Foto / Portada de la banda',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: saving
                            ? null
                            : () async {
                                final img = await DispositivoCapacidades()
                                    .seleccionarFotoArchivo();
                                if (img != null) {
                                  setDialogState(() {
                                    selectedImage = img;
                                  });
                                }
                              },
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (selectedImage != null)
                                  Image.memory(
                                    selectedImage!.bytes,
                                    fit: BoxFit.cover,
                                  )
                                else if (band.coverUrl != null &&
                                    band.coverUrl!.isNotEmpty)
                                  Image.network(
                                    band.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Center(
                                              child: Icon(
                                                Icons.music_note,
                                                color: Colors.white38,
                                                size: 48,
                                              ),
                                            ),
                                  )
                                else
                                  const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_a_photo,
                                          color: AppTheme.primaryGreen,
                                          size: 36,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Tocar para elegir foto de portada',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Cambiar foto',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Nombre
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la banda *',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Género
                      TextField(
                        controller: genreController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText:
                              'Género musical (ej. Rock Alternativo, Cumbia)',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Ubicación
                      TextField(
                        controller: locationController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Ubicación (ej. Buenos Aires, Mendoza)',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Biografía
                      TextField(
                        controller: bioController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Biografía / Historia de la banda',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Meta de donación
                      TextField(
                        controller: goalController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Meta de fondo colectivo (\$ ARS)',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          prefixText: '\$ ',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final newName = nameController.text.trim();
                          if (newName.length < 2) {
                            setDialogState(() {
                              localError = 'El nombre de la banda debe tener al menos 2 letras.';
                            });
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                            localError = null;
                          });

                          try {
                            final double goal =
                                double.tryParse(goalController.text.trim()) ??
                                band.donationGoal;

                            final result = await _viewModel.updateBandProfile(
                              currentBand: band,
                              name: newName,
                              genre: genreController.text.trim(),
                              location: locationController.text.trim(),
                              bio: bioController.text.trim(),
                              donationGoal: goal,
                              selectedImage: selectedImage,
                              fallbackBandRepository: repos.bands,
                              fallbackStorageRepository: repos.storage,
                            );
                            await session?.refreshMemberships();
                            _viewModel.load();

                            if (ctx.mounted) {
                              Navigator.pop(dialogCtx);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result.coverFailed
                                        ? 'Datos actualizados, pero no se pudo subir la nueva portada.'
                                        : '¡Datos y portada de la banda actualizados!',
                                  ),
                                  backgroundColor: result.coverFailed
                                      ? Colors.orangeAccent
                                      : AppTheme.primaryGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                              localError = 'Error al actualizar: $e';
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Guardar cambios',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildArtistProfileCard(BuildContext context, Band band) {
    return Card(
      color: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: band.coverUrl != null && band.coverUrl!.isNotEmpty
                      ? Image.network(
                          band.coverUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 80,
                                height: 80,
                                color: AppTheme.primaryGreen.withAlpha(40),
                                child: const Icon(
                                  Icons.groups,
                                  color: AppTheme.primaryGreen,
                                  size: 40,
                                ),
                              ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: AppTheme.primaryGreen.withAlpha(40),
                          child: const Icon(
                            Icons.groups,
                            color: AppTheme.primaryGreen,
                            size: 40,
                          ),
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.black,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FOTO Y PERFIL DEL ARTISTA',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    band.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (band.genre.isNotEmpty || band.location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (band.genre.isNotEmpty) band.genre,
                        if (band.location.isNotEmpty) band.location,
                      ].join(' • '),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => _showEditBandDialog(context, band),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text(
                      'Cambiar foto y datos del artista',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsSection(BandDashboardViewModel vm, Band band) {
    final albumsMap = <String, List<Song>>{};
    for (final song in vm.songs) {
      if (song.album.trim().isNotEmpty && song.album.trim() != 'Sencillo') {
        albumsMap.putIfAbsent(song.album.trim(), () => []).add(song);
      }
    }

    if (albumsMap.isEmpty) {
      return Card(
        color: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.album_outlined,
                color: AppTheme.textSecondary,
                size: 36,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Álbumes de la banda',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tus canciones actuales están como sencillos independientes. Podés agruparlas en un álbum al subir nuevos temas.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in albumsMap.entries)
          Card(
            color: AppTheme.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child:
                    entry.value.first.coverUrl != null &&
                        entry.value.first.coverUrl!.isNotEmpty
                    ? Image.network(
                        entry.value.first.coverUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 48,
                          height: 48,
                          color: Colors.white12,
                          child: const Icon(Icons.album, color: Colors.white54),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: Colors.white12,
                        child: const Icon(Icons.album, color: Colors.white54),
                      ),
              ),
              title: Text(
                entry.key,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${entry.value.length} tema(s) • Portada de álbum',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
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
      appBar: AppBar(
        title: Text('Panel: ${activeBand.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Editar datos y foto de la banda',
            onPressed: () => _showEditBandDialog(context, activeBand),
          ),
        ],
      ),
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
                    _buildArtistProfileCard(context, activeBand),
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
                      'Álbumes de la banda',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildAlbumsSection(_viewModel, activeBand),
                    const SizedBox(height: 20),
                    const Text(
                      'Canciones de la banda (con portada individual)',
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
