import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../view_models/upload_view_model.dart';

class UploadView extends StatefulWidget {
  final VoidCallback? onSongUploaded;
  final UploadViewModel? viewModel;

  const UploadView({super.key, this.onSongUploaded, this.viewModel});

  @override
  State<UploadView> createState() => _UploadViewState();
}

class _UploadViewState extends State<UploadView> {
  final _titleController = TextEditingController();
  final _albumController = TextEditingController(text: 'Demo Indie');
  late final UploadViewModel _viewModel;
  bool _ownsViewModel = false;
  bool _subirEnSegundoPlano = true;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
    } else {
      _viewModel = UploadViewModel();
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

    final success = await _viewModel.publicarTema(
      titulo: title,
      album: album.isEmpty ? 'Demo' : album,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Subir Música')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              // Aviso de límite del MVP
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Límite inicial: máximo 2 álbumes o 20 temas por banda.\nFormato: MP3 a 192 kbps.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                'Nombre del Álbum / EP',
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
                  hintText: 'Ej: Lado B',
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

              // Archivo de audio
              const Text(
                'Archivo de audio (.mp3)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                onPressed: () {
                  _viewModel.seleccionarArchivoAudio('pista_master_192k.mp3');
                },
                icon: const Icon(Icons.audio_file),
                label: Text(_viewModel.nombreArchivoAudio ?? 'Seleccionar MP3'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceElevated,
                  foregroundColor: Colors.white,
                ),
              ),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Portada: ${_viewModel.fotoPortadaPath}',
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
