import 'package:flutter/material.dart';

import '../models/playlist.dart';
import '../theme/app_theme.dart';
import '../view_models/library_view_model.dart';
import '../widgets/empty_state_view.dart';
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

  void _showEditPlaylistDialog(
    BuildContext context,
    LibraryViewModel lib,
    Playlist pl,
  ) {
    final controller = TextEditingController(text: pl.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text(
          'Editar playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nombre de la lista',
            labelStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              final ok = await lib.updatePlaylist(pl.id, name: newName);
              if (ctx.mounted) Navigator.pop(ctx);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Playlist actualizada.'
                        : (lib.error ?? 'No se pudo actualizar.'),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            child: const Text('Guardar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePlaylist(
    BuildContext context,
    LibraryViewModel lib,
    Playlist pl,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text(
          'Eliminar playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Estás seguro de que querés eliminar "${pl.name}"? Esta acción no se puede deshacer.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await lib.deletePlaylist(pl.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Playlist eliminada.'
                : (lib.error ?? 'No se pudo eliminar la playlist.'),
          ),
        ),
      );
    }
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

          if (playlists.isEmpty) {
            return EmptyStateView(
              icon: Icons.queue_music,
              title: 'Todavía no armaste ninguna playlist',
              description: 'Guardá tus canciones favoritas para escucharlas cuando quieras.',
              actionLabel: 'Crear mi primera playlist',
              onAction: () => _showNewPlaylistDialog(context, lib),
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
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  color: AppTheme.surfaceElevated,
                  tooltip: 'Opciones de playlist',
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditPlaylistDialog(context, lib, pl);
                    } else if (value == 'delete') {
                      _confirmDeletePlaylist(context, lib, pl);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.white70, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Editar nombre',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.redAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Eliminar playlist',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white54,
                            ),
                            tooltip: 'Quitar de la playlist',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppTheme.surfaceElevated,
                                  title: const Text(
                                    'Quitar tema',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: Text(
                                    '¿Querés quitar "${s.title}" de "${pl.name}"?',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                      ),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Quitar',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                final messenger = ScaffoldMessenger.of(context);
                                final ok = await lib.removeSongFromPlaylist(
                                  pl.id,
                                  s.id,
                                );
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Tema quitado de "${pl.name}".'
                                          : (lib.error ??
                                                'No se pudo quitar el tema.'),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
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
