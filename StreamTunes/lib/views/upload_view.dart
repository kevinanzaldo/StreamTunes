import 'package:flutter/material.dart';
import '../models/song.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';

class UploadView extends StatefulWidget {
  final VoidCallback? onSongUploaded;

  const UploadView({super.key, this.onSongUploaded});

  @override
  State<UploadView> createState() => _UploadViewState();
}

class _UploadViewState extends State<UploadView> {
  final _titleController = TextEditingController();
  String? _fileName;
  bool _hasCover = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el título del tema')),
      );
      return;
    }

    final newSong = Song(
      id: 'song_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      artistId: 'artist_1',
      artistName: 'Los Subterráneos',
      album: 'Demo',
      duration: const Duration(minutes: 3, seconds: 20),
      genre: 'Indie Rock',
      icon: Icons.music_note,
      gradientColors: const [Color(0xFF1DB954), Color(0xFF191414)],
      uploadedAt: DateTime.now(),
      playCount: 0,
    );

    MockData.songs.insert(0, newSong);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tema "$title" subido exitosamente.')),
    );

    _titleController.clear();
    setState(() {
      _fileName = null;
      _hasCover = false;
    });

    widget.onSongUploaded?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir Música'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // Aviso de límite del MVP (Alcances)
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
          const Text('Título del tema', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ej: Canción nueva',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surfaceElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          // Archivo
          const Text('Archivo de audio (.mp3)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _fileName = 'audio_192kbps.mp3');
            },
            icon: const Icon(Icons.audio_file),
            label: Text(_fileName ?? 'Seleccionar MP3'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceElevated,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Portada
          const Text('Foto de portada', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _hasCover = true);
            },
            icon: const Icon(Icons.image),
            label: Text(_hasCover ? 'Portada seleccionada ✓' : 'Seleccionar imagen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceElevated,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 28),

          // Botón Subir
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Subir Tema', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
