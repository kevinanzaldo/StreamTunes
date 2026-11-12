import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import '../view_models/library_view_model.dart';
import '../views/band_public_view.dart';
import 'library_scope.dart';
import 'repositories_scope.dart';
import 'reproductor_scope.dart';
import 'session_scope.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final Widget? trailing;

  const SongTile({super.key, required this.song, this.trailing});

  void _showAddDialog(BuildContext context, LibraryViewModel lib) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text(
          'Agregar a Playlist',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add, color: AppTheme.primaryGreen),
                title: const Text(
                  'Nueva playlist',
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreatePlaylistDialog(context, lib);
                },
              ),
              if (lib.playlists.isNotEmpty)
                const Divider(color: Colors.white12),
              ...lib.playlists.map((pl) {
                return ListTile(
                  leading: const Icon(
                    Icons.queue_music,
                    color: AppTheme.primaryGreen,
                  ),
                  title: Text(
                    pl.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    final ok = await lib.addSongToPlaylist(pl.id, song);
                    final mensaje = ok
                        ? 'Guardado en "${pl.name}"'
                        : (lib.error ?? 'Ya estaba en "${pl.name}"');
                    messenger.showSnackBar(SnackBar(content: Text(mensaje)));
                  },
                );
              }),
            ],
          ),
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

  void _showCreatePlaylistDialog(BuildContext context, LibraryViewModel lib) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text(
          'Nueva Playlist',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nombre de la playlist...',
            hintStyle: TextStyle(color: AppTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final created = await lib.createPlaylist(name);
              if (created && lib.playlists.isNotEmpty) {
                final newPl = lib.playlists.firstWhere(
                  (p) => p.name == name,
                  orElse: () => lib.playlists.last,
                );
                await lib.addSongToPlaylist(newPl.id, song);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Playlist "$name" creada y tema guardado.'),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(lib.error ?? 'No se pudo crear la playlist.'),
                  ),
                );
              }
            },
            child: const Text('Crear y Guardar'),
          ),
        ],
      ),
    );
  }

  /// Abre el perfil público de la banda del tema.
  Future<void> _abrirPerfilArtista(BuildContext context) async {
    final bands = RepositoriesScope.of(context).bands;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final band = await bands.getBandById(song.artistId);
      if (band == null) return;
      navigator.push(
        MaterialPageRoute(builder: (_) => BandPublicView(band: band)),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el perfil de la banda.'),
        ),
      );
    }
  }

  Widget _buildFallbackIcon(bool isPlaying) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: song.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        song.icon,
        color: isPlaying ? AppTheme.primaryGreen : Colors.white,
        size: 22,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = ReproductorScope.of(context);
    final library = LibraryScope.of(context);

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final isPlaying = player.currentSong?.id == song.id && player.isPlaying;

        Widget leadingWidget;
        if (song.coverUrl != null && song.coverUrl!.isNotEmpty) {
          leadingWidget = ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              song.coverUrl!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackIcon(isPlaying),
            ),
          );
        } else {
          leadingWidget = _buildFallbackIcon(isPlaying);
        }

        return ListTile(
          leading: leadingWidget,
          title: Text(
            song.title,
            style: TextStyle(
              color: isPlaying ? AppTheme.primaryGreen : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: InkWell(
            onTap: () => _abrirPerfilArtista(context),
            child: Text(
              song.artistName,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          trailing:
              trailing ??
              IconButton(
                icon: const Icon(Icons.playlist_add, color: Colors.white60),
                onPressed: () {
                  final session = SessionScope.maybeRead(context);
                  if (session != null && !session.isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Iniciá sesión en la pestaña Cuenta para guardar temas en playlists.',
                        ),
                      ),
                    );
                    return;
                  }
                  _showAddDialog(context, library);
                },
              ),
          onTap: () {
            player.play(song);
          },
        );
      },
    );
  }
}
