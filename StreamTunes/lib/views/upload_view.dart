import 'package:flutter/material.dart';

import '../models/band.dart';
import '../theme/app_theme.dart';
import '../view_models/upload_view_model.dart';
import '../widgets/repositories_scope.dart';
import '../widgets/session_scope.dart';
import 'create_band_view.dart';
import 'session_gate.dart';

class UploadView extends StatefulWidget {
  final VoidCallback? onSongUploaded;
  final UploadViewModel? viewModel;

  const UploadView({super.key, this.onSongUploaded, this.viewModel});

  @override
  State<UploadView> createState() => _UploadViewState();
}

class _UploadViewState extends State<UploadView> {
  final _titleController = TextEditingController();
  final _albumController = TextEditingController();
  late final UploadViewModel _viewModel;
  bool _ownsViewModel = false;
  bool _subirEnSegundoPlano = true;
  bool _loadedCupos = false;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
    } else {
      final repos = RepositoriesScope.of(context);
      _viewModel = UploadViewModel(
        songRepository: repos.songs,
        storageRepository: repos.storage,
      );
      _ownsViewModel = true;
    }
  }

  @override
  void didUpdateWidget(covariant UploadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewModel != null && widget.viewModel != oldWidget.viewModel) {
      if (_ownsViewModel) {
        _viewModel.dispose();
        _ownsViewModel = false;
      }
      _viewModel = widget.viewModel!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _albumController.dispose();
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final album = _albumController.text.trim();

    final band = SessionScope.maybeRead(context)?.activeBand;

    final success = await _viewModel.publicarTema(
      titulo: title,
      album: album,
      artistId: band?.id,
      artistName: band?.name,
      subirEnSegundoPlano: _subirEnSegundoPlano,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _subirEnSegundoPlano
                ? 'Tema "$title" enviado. Se subirá en segundo plano con conexión.'
                : 'Tema "$title" publicado con éxito.',
          ),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      _titleController.clear();
      _albumController.clear();
      _viewModel.limpiarFormulario();
      widget.onSongUploaded?.call();
    } else if (_viewModel.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_viewModel.error!),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionGate(
      title: 'Subir Música',
      message: 'Ingresá con tu cuenta para subir la música de tu banda.',
      builder: _buildUpload,
    );
  }

  /// Con sesión hace falta una banda aprobada; sin `SessionScope` (tests
  /// sueltos) se muestra el formulario directamente.
  Widget _buildUpload(BuildContext context) {
    final session = SessionScope.maybeOf(context);
    if (session == null) return _buildForm(context);

    final band = session.activeBand;
    if (band == null) {
      return _UploadBlocked(
        title: 'Subí tu música con una banda',
        text: 'Para publicar temas primero tenés que crear tu banda.',
        actionLabel: 'Crear mi banda',
        onAction: () {
          session.clearMessages();
          Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateBandView()),
          );
        },
      );
    }
    if (!band.isApproved) {
      final estado = band.status == BandStatus.suspended
          ? 'está suspendida y no puede publicar. Hablá con el Colectivo.'
          : 'todavía no está aprobada. Cuando un moderador del Colectivo la '
                'apruebe vas a poder subir música.';
      return _UploadBlocked(
        title: 'Tu banda no puede publicar todavía',
        text: 'La banda "${band.name}" $estado',
        actionLabel: 'Actualizar estado',
        onAction: session.refreshMemberships,
      );
    }

    if (!_loadedCupos) {
      _loadedCupos = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _viewModel.cargarCupos(band.id);
      });
    }

    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    final band = SessionScope.maybeOf(context)?.activeBand;

    return Scaffold(
      appBar: AppBar(title: const Text('Subir Música')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (band != null) ...[
                Text(
                  'Publicás como ${band.name}',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Aviso de límite del MVP
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _viewModel.hasReachedSongLimit
                        ? Colors.redAccent.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Límite inicial: máximo 2 álbumes o 20 temas por banda.\nFormato: MP3 a 192 kbps.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (band != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _viewModel.cargandoCupos
                            ? 'Consultando cupo disponible...'
                            : 'Cupo utilizado: ${_viewModel.songCount}/20 temas · ${_viewModel.albumCount}/2 álbumes',
                        style: TextStyle(
                          color: _viewModel.hasReachedSongLimit
                              ? Colors.redAccent
                              : AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Título
              const Text(
                'Título del tema',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ej: Canción nueva',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Álbum
              const Text(
                'Álbum / EP (opcional)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _albumController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Dejar vacío si es un tema suelto (Sencillo)',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  helperText: 'Si es un sencillo suelto, dejalo en blanco para que tenga su propia portada independiente.',
                  helperStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  filled: true,
                  fillColor: AppTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Archivo de audio
              const Text(
                'Archivo de audio (.mp3, .m4a, .wav)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                onPressed: _viewModel.subiendo
                    ? null
                    : () async {
                        await _viewModel.seleccionarAudio();
                      },
                icon: const Icon(Icons.audio_file),
                label: Text(
                  _viewModel.selectedAudio != null
                      ? '${_viewModel.selectedAudio!.name} (${_viewModel.selectedAudio!.formattedSize})'
                      : (_viewModel.nombreArchivoAudio ?? 'Seleccionar MP3'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceElevated,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_viewModel.tieneAudio) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      _viewModel.duracionAudio != null &&
                              _viewModel.duracionAudio!.inSeconds < 60
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle,
                      color: _viewModel.duracionAudio != null &&
                              _viewModel.duracionAudio!.inSeconds < 60
                          ? Colors.orangeAccent
                          : AppTheme.primaryGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _viewModel.selectedAudio != null
                            ? 'Audio: ${_viewModel.selectedAudio!.name} (${_viewModel.selectedAudio!.formattedSize})'
                            : 'Audio: ${_viewModel.nombreArchivoAudio}',
                        style: TextStyle(
                          color: _viewModel.duracionAudio != null &&
                                  _viewModel.duracionAudio!.inSeconds < 60
                              ? Colors.orangeAccent
                              : AppTheme.primaryGreen,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (_viewModel.duracionAudio != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Duración: ${_viewModel.duracionAudio!.inMinutes}:${(_viewModel.duracionAudio!.inSeconds % 60).toString().padLeft(2, '0')} min'
                    '${_viewModel.duracionAudio!.inSeconds < 60 ? " ❌ Mínimo requerido: 1 minuto (60 s)" : " ✅ Válido"}',
                    style: TextStyle(
                      color: _viewModel.duracionAudio!.inSeconds < 60
                          ? Colors.redAccent
                          : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: _viewModel.duracionAudio!.inSeconds < 60
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),

              // Foto de portada (Patrón Capabilities y Policies - Bloque 3)
              const Text(
                'Foto de portada',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              if (_viewModel.cargandoCapacidades)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    // Botón de Cámara: Solo visible si el dispositivo tiene cámara disponible
                    if (_viewModel.tieneCamara)
                      ElevatedButton.icon(
                        onPressed: _viewModel.tomarFotoConCamara,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Tomar con cámara'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.surfaceElevated,
                          foregroundColor: Colors.white,
                        ),
                      ),

                    // Opción de Galería: siempre disponible
                    ElevatedButton.icon(
                      onPressed: _viewModel.seleccionarFotoDeGaleria,
                      icon: const Icon(Icons.photo_library),
                      label: Text(
                        _viewModel.tienePortada
                            ? 'Cambiar imagen'
                            : 'Seleccionar de galería',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceElevated,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),

              if (_viewModel.tienePortada) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      if (_viewModel.selectedImage != null &&
                          _viewModel.selectedImage!.bytes.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(
                            _viewModel.selectedImage!.bytes,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.image, color: Colors.white54),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.primaryGreen,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Portada lista',
                                  style: TextStyle(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _viewModel.fotoPortadaPath ?? 'Foto seleccionada',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Quitar foto',
                        onPressed: _viewModel.quitarFoto,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Opción de subida en segundo plano con Workmanager (Bloque 6)
              SwitchListTile(
                value: _subirEnSegundoPlano,
                onChanged: (val) {
                  setState(() {
                    _subirEnSegundoPlano = val;
                  });
                },
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Subir en segundo plano (Workmanager)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Continúa subiendo aunque minimices la app; requiere conexión.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                activeTrackColor: AppTheme.primaryGreen,
              ),
              const SizedBox(height: 20),

              // Botón Subir
              ElevatedButton(
                onPressed: _viewModel.subiendo ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _viewModel.subiendo
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Publicar Tema',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Aviso cuando la persona todavía no puede publicar (sin banda, o con la
/// banda pendiente o suspendida), con una acción para avanzar.
class _UploadBlocked extends StatelessWidget {
  const _UploadBlocked({
    required this.title,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir Música')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 40,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.black,
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
