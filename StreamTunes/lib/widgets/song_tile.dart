import 'package:flutter/material.dart';
import '../models/song.dart';
import '../state/player_model.dart';
import '../state/library_model.dart';
import '../theme/app_theme.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final PlayerModel playerModel;
  final LibraryModel libraryModel;

  const SongTile({
    super.key,
    required this.song,
    required this.playerModel,
    required this.libraryModel,
  });

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Agregar a Playlist', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: libraryModel.playlists.map((pl) {
            return ListTile(
              leading: const Icon(Icons.queue_music, color: AppTheme.primaryGreen),
              title: Text(pl.name, style: const TextStyle(color: Colors.white)),
              onTap: () {
                libraryModel.addSongToPlaylist(pl.id, song);
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
    return ListenableBuilder(
      listenable: playerModel,
      builder: (context, _) {
        final isPlaying = playerModel.currentSong?.id == song.id && playerModel.isPlaying;

        return ListTile(
          leading: Icon(song.icon, color: isPlaying ? AppTheme.primaryGreen : Colors.white70),
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
            onPressed: () => _showAddDialog(context),
          ),
          onTap: () {
            playerModel.playSong(song);
          },
        );
      },
    );
  }
}
