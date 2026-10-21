import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/artist.dart';
import '../state/library_model.dart';
import '../state/player_model.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';

class ArtistDetailView extends StatelessWidget {
  final Artist artist;
  final PlayerModel playerModel;
  final LibraryModel libraryModel;

  const ArtistDetailView({
    super.key,
    required this.artist,
    required this.playerModel,
    required this.libraryModel,
  });

  @override
  Widget build(BuildContext context) {
    // RF-01: Canciones más escuchadas del artista
    final artistSongs = MockData.getSongsByArtist(artist.id)
      ..sort((a, b) => b.playCount.compareTo(a.playCount));

    return Scaffold(
      appBar: AppBar(title: Text(artist.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // Portada y Nombre (RF-01)
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.surfaceElevated,
              child: Icon(
                artist.avatarIcon,
                size: 40,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              artist.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Center(
            child: Text(
              '${artist.genre} • ${artist.location}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Biografía corta (RF-01)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              artist.bio,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),

          // Enlaces a redes sociales (RF-01)
          const Text(
            'Redes sociales',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: artist.socialLinks.entries.map((entry) {
              return Chip(
                label: Text('${entry.key}: ${entry.value}'),
                labelStyle: const TextStyle(fontSize: 11, color: Colors.white),
                backgroundColor: AppTheme.surfaceElevated,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // RF-06: Panel de Estadísticas (Privado de la banda, actualización diaria)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.bar_chart,
                      color: AppTheme.primaryGreen,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Panel de Estadísticas (Solo Artista)',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ayer te escucharon: ${artist.yesterdayPlays} veces (corte diario)',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Canciones más escuchadas (RF-01)
          const Text(
            'Canciones más escuchadas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...artistSongs.map((song) {
            return SongTile(
              song: song,
              playerModel: playerModel,
              libraryModel: libraryModel,
            );
          }),
        ],
      ),
    );
  }
}
