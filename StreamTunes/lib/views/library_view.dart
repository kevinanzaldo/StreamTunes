import 'package:flutter/material.dart';

import '../state/library_model.dart';
import '../state/player_model.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';

class LibraryView extends StatelessWidget {
  final PlayerModel playerModel;
  final LibraryModel libraryModel;

  const LibraryView({
    super.key,
    required this.playerModel,
    required this.libraryModel,
  });

  void _showNewPlaylistDialog(BuildContext context) {
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
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                libraryModel.createPlaylist(name);
                Navigator.pop(ctx);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primaryGreen),
            tooltip: 'Crear playlist',
            onPressed: () => _showNewPlaylistDialog(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: libraryModel,
        builder: (context, _) {
          final playlists = libraryModel.playlists;

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
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
                        return SongTile(
                          song: s,
                          playerModel: playerModel,
                          libraryModel: libraryModel,
                        );
                      }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
