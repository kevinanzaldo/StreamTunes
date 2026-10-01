import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/song.dart';
import '../state/player_model.dart';
import '../state/library_model.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import 'artist_detail_view.dart';

class HomeView extends StatelessWidget {
  final PlayerModel playerModel;
  final LibraryModel libraryModel;

  const HomeView({
    super.key,
    required this.playerModel,
    required this.libraryModel,
  });

  @override
  Widget build(BuildContext context) {
    // Ordenar canciones por fecha de subida (RF-03)
    final sortedSongs = List<Song>.from(MockData.songs)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('StreamTunes', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          // Acceso a bandas independientes
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Bandas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: MockData.artists.length,
              itemBuilder: (context, index) {
                final artist = MockData.artists[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    avatar: Icon(artist.avatarIcon, size: 16, color: AppTheme.primaryGreen),
                    label: Text(artist.name),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    backgroundColor: AppTheme.surfaceElevated,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArtistDetailView(
                            artist: artist,
                            playerModel: playerModel,
                            libraryModel: libraryModel,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          const Divider(color: Colors.white12, height: 24),

          // RF-03: Últimos lanzamientos
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Últimos lanzamientos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          ...sortedSongs.map((song) {
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
