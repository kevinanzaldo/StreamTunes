import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'now_playing_modal.dart';
import 'reproductor_scope.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final reproductor = ReproductorScope.maybeOf(context);
    if (reproductor == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: reproductor,
      builder: (context, _) {
        final song = reproductor.currentSong;
        if (song == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => NowPlayingModal.show(context, reproductor),
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceElevated,
              border: Border(
                top: BorderSide(color: Colors.white10, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Container(
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
                  child: Icon(song.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artistName,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white),
                  onPressed: reproductor.previous,
                  tooltip: 'Anterior',
                ),
                IconButton(
                  icon: Icon(
                    reproductor.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: AppTheme.primaryGreen,
                    size: 38,
                  ),
                  onPressed: reproductor.togglePlay,
                  tooltip: reproductor.isPlaying ? 'Pausar' : 'Reproducir',
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                  onPressed: reproductor.next,
                  tooltip: 'Siguiente',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
