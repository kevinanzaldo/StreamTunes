import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/band.dart';
import '../models/song.dart';
import '../services/dispositivo_capacidades.dart';
import '../theme/app_theme.dart';
import '../view_models/band_dashboard_view_model.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/player_bar.dart';
import '../widgets/repositories_scope.dart';
import '../widgets/session_scope.dart';
import 'band_public_view.dart';
import 'upload_view.dart';

/// Panel privado de gestión para miembros de una banda ("Mi banda").
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

  Widget _buildQrShareCard(BuildContext context, BandDashboardViewModel vm) {
    return Card(
      key: const ValueKey('band_qr_card'),
      color: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 380;
            final qrBox = Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: vm.qrDeepLink,
                version: QrVersions.auto,
                size: 120,
                backgroundColor: Colors.white,
              ),
            );
            final infoCol = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.qr_code_2,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'QR para tus recitales',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Se genera en tu celular sin señal. Quien lo escanee puede seguir a la banda al instante sin registrarse.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('copy_qr_link_button'),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(
                          ClipboardData(text: vm.qrDeepLink),
                        );
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Link copiado para compartir o imprimir.',
                            ),
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        side: const BorderSide(color: AppTheme.primaryGreen),
                      ),
                    ),
                  ],
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: qrBox),
                  const SizedBox(height: 12),
                  infoCol,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                qrBox,
                const SizedBox(width: 16),
                Expanded(child: infoCol),
              ],
            );
          },
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
                    'Métricas de la banda',
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
              'Totales calculados en el servidor a partir de las escuchas de tu público.',
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
                        'Consultando estadísticas...',
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
                          'Días activos',
                          '${vm.metrics!.reproduccionesPorDia.length}',
                        ),
                      ],
                    ),
                    if (vm.metrics!.topTemas.isNotEmpty) ...[
                      const Divider(color: Colors.white12, height: 20),
                      const Text(
                        'Temas más escuchados:',
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
                      'Top Fans del período:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (vm.metrics!.rankingOyentes.isEmpty)
                      const Text(
                        'Todavía no hay reproducciones registradas para tu banda. ¡Compartí tu perfil para empezar a sumar minutos!',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      )
                    else
                      for (final o in vm.metrics!.rankingOyentes.take(5))
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
                                '${o.minutos} min',
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
                label: const Text('Actualizar estadísticas'),
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
                  'Ver estadísticas ahora',
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
              'Editar datos, foto y tienda de merch',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddEventDialog(BuildContext context, Band band) async {
    final titleCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: band.location);
    var selectedDate = DateTime.now().add(const Duration(days: 7));

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          title: const Text(
            'Nueva fecha en agenda',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nombre del show *',
                    hintText: 'Ej: Noche Under en el Sótano',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: venueCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Lugar / Espacio *',
                    hintText: 'Ej: Club Cultural',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cityCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Ciudad'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.calendar_today,
                    color: AppTheme.primaryGreen,
                  ),
                  title: Text(
                    'Fecha: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          21,
                          0,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                if (titleCtrl.text.trim().length < 2 ||
                    venueCtrl.text.trim().length < 2) {
                  return;
                }
                final ok = await _viewModel.addEvent(
                  title: titleCtrl.text.trim(),
                  venue: venueCtrl.text.trim(),
                  city: cityCtrl.text.trim(),
                  eventDate: selectedDate,
                );
                if (dialogCtx.mounted && ok) {
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text('Guardar fecha'),
            ),
          ],
        ),
      ),
    );
  }

  Future<SelectedImageFile?> _pedirFoto(
    BuildContext context, {
    required String titulo,
  }) async {
    final tieneCamara = await DispositivoCapacidades.actual.tieneCamara;
    if (!context.mounted) return null;
    if (!tieneCamara) {
      return DispositivoCapacidades.actual.seleccionarFotoArchivo();
    }
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: AppTheme.primaryGreen,
              ),
              title: const Text(
                'Sacar foto con la cámara',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppTheme.primaryGreen,
              ),
              title: const Text(
                'Elegir de la galería',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    if (source == 'camera') {
      return DispositivoCapacidades.actual.tomarFotoArchivo();
    } else {
      return DispositivoCapacidades.actual.seleccionarFotoArchivo();
    }
  }

  Future<void> _addShowPhotoFlow(BuildContext context) async {
    final img = await _pedirFoto(context, titulo: 'Agregar foto de show');
    if (img == null || !context.mounted) return;
    final captionCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text(
          'Agregar foto de show',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                img.bytes,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: captionCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Descripción breve (opcional)',
                hintText: 'Ej: Recital en Uniclub',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Subir foto'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _viewModel.addShowPhoto(img, caption: captionCtrl.text.trim());
    }
  }

  Future<void> _showEditBandDialog(BuildContext context, Band band) async {
    final nameController = TextEditingController(text: band.name);
    final genreController = TextEditingController(text: band.genre);
    final bioController = TextEditingController(text: band.bio);
    final locationController = TextEditingController(text: band.location);
    final merchController = TextEditingController(text: band.merchUrl ?? '');
    final goalController = TextEditingController(
      text: band.donationGoal > 0 ? band.donationGoal.toInt().toString() : '',
    );
    SelectedImageFile? selectedImage;
    bool saving = false;
    String? localError;

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
                                final img = await _pedirFoto(
                                  context,
                                  titulo: 'Foto / Portada de la banda',
                                );
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
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la banda *',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      TextField(
                        controller: locationController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Ubicación (ej. Buenos Aires, Mendoza)',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      TextField(
                        controller: merchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText:
                              'Link a tienda de merch (remeras, vinilos)',
                          hintText: 'https://mitienda.com/banda',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                              merchUrl: merchController.text.trim(),
                              selectedImage: selectedImage,
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
                    'PERFIL DE LA BANDA',
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
                      'Cambiar foto y datos',
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

  Widget _buildEventsSection(
    BuildContext context,
    BandDashboardViewModel vm,
    Band band,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const Text(
              'Agenda de fechas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAddEventDialog(context, band),
              icon: const Icon(
                Icons.add,
                color: AppTheme.primaryGreen,
                size: 18,
              ),
              label: const Text(
                'Agregar fecha',
                style: TextStyle(color: AppTheme.primaryGreen),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (vm.events.isEmpty)
          Card(
            color: AppTheme.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Todavía no cargaste próximos shows. Agregá una fecha para que tus fans sepan dónde tocás.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ),
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
              itemCount: vm.events.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final ev = vm.events[index];
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
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white54,
                    ),
                    onPressed: () => vm.deleteEvent(ev.id),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPhotosSection(BuildContext context, BandDashboardViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const Text(
              'Fotos de shows',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => _addShowPhotoFlow(context),
              icon: const Icon(
                Icons.add_a_photo,
                color: AppTheme.primaryGreen,
                size: 18,
              ),
              label: const Text(
                'Subir foto',
                style: TextStyle(color: AppTheme.primaryGreen),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (vm.photos.isEmpty)
          Card(
            color: AppTheme.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Subí fotos de tus recitales o ensayos para mostrarlas en la vista pública de compu y celu.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: vm.photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final photo = vm.photos[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        photo.photoUrl,
                        width: 140,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 140,
                          height: 120,
                          color: Colors.white10,
                          child: const Icon(Icons.image, color: Colors.white38),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                          onPressed: () => vm.deleteShowPhoto(photo.id),
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
        child: EmptyStateView(
          icon: Icons.music_note,
          title: 'Todavía no subiste ninguna canción',
          description: 'Empezá a compartir tu música con tus fans.',
          actionLabel: 'Subir mi primer tema',
          onAction: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UploadView(onSongUploaded: () => vm.load()),
              ),
            );
          },
          secondaryActionLabel: 'Recargar',
          onSecondaryAction: () => vm.load(),
          compact: true,
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

  Widget _buildTopFansSection(BandDashboardViewModel vm) {
    if (vm.topFans.isEmpty) {
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
                  'Aún no hay suficientes reproducciones para armar el Top 10 de fans.',
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
        itemCount: vm.topFans.length,
        separatorBuilder: (_, _) =>
            const Divider(color: Colors.white10, height: 1),
        itemBuilder: (context, index) {
          final fan = vm.topFans[index];
          final hasAvatar =
              fan.isPublic &&
              fan.avatarUrl != null &&
              fan.avatarUrl!.isNotEmpty;

          return ListTile(
            leading: hasAvatar
                ? CircleAvatar(backgroundImage: NetworkImage(fan.avatarUrl!))
                : CircleAvatar(
                    backgroundColor: AppTheme.surface,
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            title: Text(
              fan.nombre,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: fan.isPublic
                ? const Text(
                    'Perfil público activo',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  )
                : const Text(
                    'Modo privacidad',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
            trailing: Text(
              '${fan.minutos} min',
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
                    const SizedBox(height: 16),
                    _buildQrShareCard(context, _viewModel),
                    const SizedBox(height: 20),
                    _buildMetricsSection(_viewModel),
                    const SizedBox(height: 20),
                    const Text(
                      'Top 10 fans en vivo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildTopFansSection(_viewModel),
                    const SizedBox(height: 20),
                    _buildEventsSection(context, _viewModel, activeBand),
                    const SizedBox(height: 20),
                    _buildPhotosSection(context, _viewModel),
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
