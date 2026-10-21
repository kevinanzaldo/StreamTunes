import 'package:flutter/material.dart';

import '../state/player_model.dart';
import '../theme/app_theme.dart';

class PlayerBar extends StatelessWidget {
  final PlayerModel playerModel;

  const PlayerBar({super.key, required this.playerModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerModel,
      builder: (context, _) {
        final song = playerModel.currentSong;
        if (song == null) {
          return const SizedBox.shrink();
        }

        return Container(
          color: AppTheme.surfaceElevated,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(song.icon, color: AppTheme.primaryGreen, size: 28),
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
                icon: Icon(
                  playerModel.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: AppTheme.primaryGreen,
                  size: 36,
                ),
                onPressed: () => playerModel.togglePlay(),
              ),
            ],
          ),
        );
      },
    );
  }
}
