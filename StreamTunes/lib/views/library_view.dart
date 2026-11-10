import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../view_models/library_view_model.dart';
import '../widgets/library_scope.dart';
import '../widgets/song_tile.dart';
import 'session_gate.dart';

class LibraryView extends StatelessWidget {
  const LibraryView({super.key});

  void _showNewPlaylistDialog(BuildContext context, LibraryViewModel lib) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text(
          'Nueva Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nombre de la lista',
            hintStyle: TextStyle(color: AppTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              final ok = await lib.createPlaylist(name);
              if (ctx.mounted) Navigator.pop(ctx);
              if (!ok && lib.error != null) {
                messenger.showSnackBar(SnackBar(content: Text(lib.error!)));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            child: const Text('Crear', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SessionGate(
      title: 'Playlists',
      message: 'Ingresá para armar tus playlists y ver tus donaciones.',
      builder: _buildLibrary,
    );
  }

  Widget _buildLibrary(BuildContext context) {
    final lib = LibraryScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primaryGreen),
            tooltip: 'Crear playlist',
            onPressed: () => _showNewPlaylistDialog(context, lib),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: lib,
        builder: (context, _) {
          final playlists = lib.playlists;

          if (lib.isLoading && playlists.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (lib.loadFailed && playlists.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lib.error ?? 'No se pudo cargar tu biblioteca.',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: lib.load,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final pl = playlists[index];
              return ExpansionTile(
                leading: const Icon(
                  Icons.queue_music,
                  color: AppTheme.primaryGreen,
                ),
                title: Text(
                  pl.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${pl.songs.length} temas',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                children: pl.songs.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text(
                            'Lista vacía.',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      ]
                    : pl.songs.map((s) {
                        return SongTile(song: s);
                      }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
