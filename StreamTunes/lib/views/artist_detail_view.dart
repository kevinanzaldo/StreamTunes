import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/artist.dart';
import '../theme/app_theme.dart';
import '../view_models/artist_detail_view_model.dart';
import '../view_models/library_view_model.dart';
import '../view_models/reproductor_view_model.dart';
import '../widgets/song_tile.dart';

class ArtistDetailView extends StatefulWidget {
  final Artist artist;
  final ReproductorViewModel? playerModel;
  final LibraryViewModel? libraryModel;
  final ArtistDetailViewModel? viewModel;

  const ArtistDetailView({
    super.key,
    required this.artist,
    this.playerModel,
    this.libraryModel,
    this.viewModel,
  });

  @override
  State<ArtistDetailView> createState() => _ArtistDetailViewState();
}

class _ArtistDetailViewState extends State<ArtistDetailView> {
  late final ArtistDetailViewModel _viewModel;
  bool _ownsViewModel = false;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
    } else {
      _viewModel = ArtistDetailViewModel(artist: widget.artist);
      _ownsViewModel = true;
    }
  }

  @override
  void didUpdateWidget(covariant ArtistDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewModel != null && widget.viewModel != oldWidget.viewModel) {
      if (_ownsViewModel) {
        _viewModel.dispose();
        _ownsViewModel = false;
      }
      _viewModel = widget.viewModel!;
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artistSongs = MockData.getSongsByArtist(widget.artist.id)
      ..sort((a, b) => b.playCount.compareTo(a.playCount));

    return Scaffold(
      appBar: AppBar(title: Text(widget.artist.name)),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              // Alerta de donación en vivo recibida vía Stream (Bloque 5)
              if (_viewModel.mostrarAlertaDonacion &&
                  _viewModel.ultimaDonacion != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1DB954), Color(0xFF191414)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '¡Nueva donación en vivo recibida!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '+${_viewModel.ultimaDonacion!.formattedAmount} • "${_viewModel.ultimaDonacion!.message ?? 'Apoyo independiente'}"',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 18,
                        ),
                        onPressed: _viewModel.ocultarAlertaDonacion,
                      ),
                    ],
                  ),
                ),

              // Portada y Nombre
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.surfaceElevated,
                  child: Icon(
                    widget.artist.avatarIcon,
                    size: 40,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  widget.artist.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Center(
                child: Text(
                  '${widget.artist.genre} • ${widget.artist.location}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Biografía
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.artist.bio,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),

              // Progreso de donaciones
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Fondo de apoyo a la banda',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${widget.artist.donationsCollected.toStringAsFixed(0)} / \$${widget.artist.donationGoal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _viewModel.progresoDonaciones,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryGreen,
                      ),
                      minHeight: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Enlaces a redes sociales
              const Text(
                'Redes sociales',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: widget.artist.socialLinks.entries.map((entry) {
                  return Chip(
                    label: Text('${entry.key}: ${entry.value}'),
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                    ),
                    backgroundColor: AppTheme.surfaceElevated,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Panel de Estadísticas con Isolate.run (Bloque 4)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.insights,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Métricas en Segundo Plano (Isolate)',
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ayer te escucharon: ${widget.artist.yesterdayPlays} veces.',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    if (_viewModel.calculandoEstadisticas)
                      const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Calculando 50.000 reproducciones en Isolate...',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (_viewModel.totalMinutosEscuchados != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '⏱ Total: ${_viewModel.totalMinutosEscuchados} minutos calculados sin trabar la música',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _viewModel.calcularEstadisticasIsolate,
                        icon: const Icon(Icons.calculate, size: 18),
                        label: const Text(
                          'Calcular minutos totales (50k registros)',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.surfaceElevated,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    if (_viewModel.errorEstadisticas != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _viewModel.errorEstadisticas!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Canciones más escuchadas
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
                  playerModel: widget.playerModel,
                  libraryModel: widget.libraryModel,
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
