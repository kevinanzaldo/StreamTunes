import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../view_models/home_view_model.dart';
import '../widgets/repositories_scope.dart';
import '../widgets/song_tile.dart';
import 'band_public_view.dart';

class HomeView extends StatefulWidget {
  /// Si es null, la vista crea el suyo con los repositorios de `RepositoriesScope`
  /// (modo demo o Supabase según la configuración).
  final HomeViewModel? viewModel;

  const HomeView({super.key, this.viewModel});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
      _ownsViewModel = false;
    } else {
      final repositories = RepositoriesScope.of(context);
      _viewModel = HomeViewModel(
        songRepository: repositories.songs,
        bandRepository: repositories.bands,
      );
      _ownsViewModel = true;
    }
    _viewModel.load();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'StreamTunes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          switch (_viewModel.status) {
            case HomeStatus.loading:
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              );
            case HomeStatus.error:
              return _buildError();
            case HomeStatus.ready:
              return _buildContent(context);
          }
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 48,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'No pudimos cargar la música. Revisá tu conexión e intentá de nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _viewModel.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final bands = _viewModel.bands;
    final filteredBands = _viewModel.filteredBands;
    final songs = _viewModel.filteredSongs;
    final isSearching = _viewModel.searchQuery.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _viewModel.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          // Buscador de canciones o bandas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const ValueKey('home_search_input'),
              onChanged: _viewModel.setSearchQuery,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar canción o banda...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                suffixIcon: isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                        onPressed: () => _viewModel.setSearchQuery(''),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filtro por género
          if (_viewModel.availableGenres.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _viewModel.selectedGenre == null,
                    onSelected: (_) => _viewModel.selectGenre(null),
                    selectedColor: AppTheme.primaryGreen,
                    backgroundColor: AppTheme.surfaceElevated,
                    labelStyle: TextStyle(
                      color: _viewModel.selectedGenre == null
                          ? Colors.black
                          : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ..._viewModel.availableGenres.map((genre) {
                    final isSelected = _viewModel.selectedGenre == genre;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(genre),
                        selected: isSelected,
                        onSelected: (_) => _viewModel.selectGenre(genre),
                        selectedColor: AppTheme.primaryGreen,
                        backgroundColor: AppTheme.surfaceElevated,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Vista de BÚSQUEDA ACTIVA
          if (isSearching) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.groups, color: AppTheme.primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Bandas (${filteredBands.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (filteredBands.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'No se encontraron bandas con "${_viewModel.searchQuery}".',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              )
            else
              ...filteredBands.map((band) {
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: band.coverUrl != null && band.coverUrl!.isNotEmpty
                        ? Image.network(
                            band.coverUrl!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _bandDefaultAvatar(band),
                          )
                        : _bandDefaultAvatar(band),
                  ),
                  title: Text(
                    band.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${band.genre} · ${band.location}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppTheme.primaryGreen,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BandPublicView(band: band),
                      ),
                    );
                  },
                );
              }),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(color: Colors.white12),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: AppTheme.primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Canciones (${songs.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (songs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'No se encontraron canciones con "${_viewModel.searchQuery}".',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              )
            else
              ...songs.map((song) => SongTile(song: song)),
          ] else ...[
            // Acceso a bandas independientes (Modo normal sin búsqueda)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Bandas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            if (bands.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Todavía no hay bandas publicadas.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              )
            else
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: bands.length,
                  itemBuilder: (context, index) {
                    final band = bands[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        avatar: const Icon(
                          Icons.music_note,
                          size: 16,
                          color: AppTheme.primaryGreen,
                        ),
                        label: Text(band.name),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        backgroundColor: AppTheme.surfaceElevated,
                        side: const BorderSide(color: Colors.white24, width: 0.8),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BandPublicView(band: band),
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            if (songs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Todavía no hay lanzamientos.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              )
            else
              ...songs.map((song) => SongTile(song: song)),
          ],
        ],
      ),
    );
  }

  Widget _bandDefaultAvatar(dynamic band) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.groups,
        color: AppTheme.primaryGreen,
        size: 24,
      ),
    );
  }
}
