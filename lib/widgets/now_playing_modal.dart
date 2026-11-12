import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../view_models/reproductor_view_model.dart';
import '../views/band_public_view.dart';
import 'repositories_scope.dart';
import 'reproductor_scope.dart';

class NowPlayingModal extends StatefulWidget {
  const NowPlayingModal({super.key});

  static void show(BuildContext context, [ReproductorViewModel? reproductor]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NowPlayingModal(),
    );
  }

  @override
  State<NowPlayingModal> createState() => _NowPlayingModalState();
}

class _NowPlayingModalState extends State<NowPlayingModal> {
  bool _showLyricsOverlay = false;

  @override
  Widget build(BuildContext context) {
    final reproductor = ReproductorScope.of(context);

    return ListenableBuilder(
      listenable: reproductor,
      builder: (context, _) {
        final song = reproductor.currentSong;
        if (song == null) {
          return const SizedBox.shrink();
        }

        final hasLyrics = reproductor.hasLyrics;
        final showLyrics = hasLyrics && _showLyricsOverlay;

        return Container(
          height: MediaQuery.sizeOf(context).height * 0.94,
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white70,
                      size: 32,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (hasLyrics)
                    IconButton(
                      key: const ValueKey('now_playing_lyrics_toggle'),
                      tooltip: showLyrics ? 'Ver portada' : 'Ver letra',
                      icon: Icon(
                        showLyrics ? Icons.album : Icons.lyrics_outlined,
                        color: showLyrics
                            ? AppTheme.primaryGreen
                            : Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _showLyricsOverlay = !_showLyricsOverlay;
                        });
                      },
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),

              // Portada gigante (o letra sincronizada tipo karaoke si la banda cargó LRC y se activó)
              Expanded(
                child: showLyrics
                    ? _KaraokeLyricsPanel(reproductor: reproductor)
                    : Center(
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child:
                                  song.coverUrl != null &&
                                      song.coverUrl!.isNotEmpty
                                  ? Image.network(
                                      song.coverUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                            song.icon,
                                            size: 110,
                                            color: Colors.white,
                                          ),
                                    )
                                  : Icon(
                                      song.icon,
                                      size: 110,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ),
              ),

              // Vista previa compacta de la línea activa cuando hay letra LRC
              if (hasLyrics && !showLyrics) ...[
                const SizedBox(height: 12),
                _CompactLyricBanner(
                  reproductor: reproductor,
                  onTap: () => setState(() => _showLyricsOverlay = true),
                ),
              ],

              const SizedBox(height: 20),

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
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.maybeOf(
                              context,
                            );
                            final band = await RepositoriesScope.of(context)
                                .bands
                                .getBandById(song.artistId);
                            if (!context.mounted) return;
                            if (band == null) {
                              messenger?.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se encontró el perfil público de la banda.',
                                  ),
                                ),
                              );
                              return;
                            }
                            navigator.pop();
                            navigator.push(
                              MaterialPageRoute(
                                builder: (_) => BandPublicView(band: band),
                              ),
                            );
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
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _CompactLyricBanner extends StatelessWidget {
  const _CompactLyricBanner({required this.reproductor, required this.onTap});

  final ReproductorViewModel reproductor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lines = reproductor.lyricsLines;
    final activeIdx = reproductor.activeLyricIndex;
    final lineText = activeIdx >= 0 && activeIdx < lines.length
        ? lines[activeIdx].text
        : lines.first.text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.lyrics, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lineText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.open_in_full, size: 14, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _KaraokeLyricsPanel extends StatelessWidget {
  const _KaraokeLyricsPanel({required this.reproductor});

  final ReproductorViewModel reproductor;

  @override
  Widget build(BuildContext context) {
    final lines = reproductor.lyricsLines;
    final activeIdx = reproductor.activeLyricIndex;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ListView.separated(
        itemCount: lines.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final line = lines[index];
          final isActive = index == activeIdx;
          return GestureDetector(
            onTap: () => reproductor.seekTo(line.timestamp),
            child: Text(
              line.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? AppTheme.primaryGreen : Colors.white60,
                fontSize: isActive ? 20 : 15,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                height: 1.35,
              ),
            ),
          );
        },
      ),
    );
  }
}
