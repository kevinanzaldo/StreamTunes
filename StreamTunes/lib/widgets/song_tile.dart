import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import '../view_models/library_view_model.dart';
import '../view_models/reproductor_view_model.dart';
import 'library_scope.dart';
import 'reproductor_scope.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final ReproductorViewModel? playerModel;
  final LibraryViewModel? libraryModel;

  const SongTile({
    super.key,
    required this.song,
    this.playerModel,
    this.libraryModel,
  });

  void _showAddDialog(BuildContext context, LibraryViewModel lib) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text(
          'Agregar a Playlist',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: lib.playlists.map((pl) {
            return ListTile(
              leading: const Icon(
                Icons.queue_music,
                color: AppTheme.primaryGreen,
              ),
              title: Text(pl.name, style: const TextStyle(color: Colors.white)),
              onTap: () {
                lib.addSongToPlaylist(pl.id, song);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Guardado en "${pl.name}"')),
                );
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = playerModel ?? ReproductorScope.of(context);
    final library = libraryModel ?? LibraryScope.of(context);

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final isPlaying = player.currentSong?.id == song.id && player.isPlaying;

        return ListTile(
          leading: Icon(
            song.icon,
            color: isPlaying ? AppTheme.primaryGreen : Colors.white70,
          ),
          title: Text(
            song.title,
            style: TextStyle(
              color: isPlaying ? AppTheme.primaryGreen : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            song.artistName,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.playlist_add, color: Colors.white60),
            onPressed: () => _showAddDialog(context, library),
          ),
          onTap: () {
            player.play(song);
          },
        );
      },
    );
  }
}
