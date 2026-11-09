import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../view_models/reproductor_view_model.dart';
import '../views/artist_detail_view.dart';

class NowPlayingModal extends StatelessWidget {
  final ReproductorViewModel reproductor;

  const NowPlayingModal({super.key, required this.reproductor});

  static void show(BuildContext context, ReproductorViewModel reproductor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NowPlayingModal(reproductor: reproductor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: reproductor,
      builder: (context, _) {
        final song = reproductor.currentSong;
        if (song == null) {
          return const SizedBox.shrink();
        }

        return Container(
          height: MediaQuery.sizeOf(context).height * 0.9,
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Indicador de arrastre / botón minimizar
              IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white70,
                  size: 32,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),

              // Portada grande con gradiente
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: song.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: song.gradientColors.first.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Icon(song.icon, size: 100, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Información del tema
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () {
                            final artist = MockData.getArtistById(
                              song.artistId,
                            );
                            if (artist != null) {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArtistDetailView(
                                    artist: artist,
                                    playerModel: reproductor,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '${song.artistName} • ${song.album}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right,
                                color: AppTheme.primaryGreen,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Slider de progreso
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbColor: Colors.white,
                  activeTrackColor: AppTheme.primaryGreen,
                  inactiveTrackColor: Colors.white24,
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  value: reproductor.progress,
                  onChanged: (val) {
                    final targetMs =
                        (val * reproductor.totalDuration.inMilliseconds)
                            .toInt();
                    reproductor.seekTo(Duration(milliseconds: targetMs));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      reproductor.formattedCurrentPosition,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      reproductor.formattedTotalDuration,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Controles de reproducción principales
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: reproductor.isShuffle
                          ? AppTheme.primaryGreen
                          : Colors.white60,
                      size: 24,
                    ),
                    onPressed: reproductor.toggleShuffle,
                    tooltip: 'Modo aleatorio',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_previous,
                      color: Colors.white,
                      size: 38,
                    ),
                    onPressed: reproductor.previous,
                    tooltip: 'Anterior',
                  ),
                  IconButton(
                    icon: Icon(
                      reproductor.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: AppTheme.primaryGreen,
                      size: 68,
                    ),
                    onPressed: reproductor.togglePlay,
                    tooltip: reproductor.isPlaying ? 'Pausar' : 'Reproducir',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next,
                      color: Colors.white,
                      size: 38,
                    ),
                    onPressed: reproductor.next,
                    tooltip: 'Siguiente',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.repeat,
                      color: reproductor.isRepeat
                          ? AppTheme.primaryGreen
                          : Colors.white60,
                      size: 24,
                    ),
                    onPressed: reproductor.toggleRepeat,
                    tooltip: 'Repetir',
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
