import 'package:flutter/material.dart';
import '../state/player_model.dart';
import '../state/library_model.dart';
import '../widgets/player_bar.dart';
import 'home_view.dart';
import 'upload_view.dart';
import 'library_view.dart';

class MainNavigationShell extends StatefulWidget {
  final PlayerModel playerModel;
  final LibraryModel libraryModel;

  const MainNavigationShell({
    super.key,
    required this.playerModel,
    required this.libraryModel,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeView(playerModel: widget.playerModel, libraryModel: widget.libraryModel),
      UploadView(
        onSongUploaded: () {
          setState(() {
            _currentIndex = 0; // Vuelve al inicio para ver el tema publicado
          });
        },
      ),
      LibraryView(playerModel: widget.playerModel, libraryModel: widget.libraryModel),
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Mantener la pantalla activa sin reconstrucciones raras
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),

          // Reproductor fijo flotante abajo
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: PlayerBar(
                playerModel: widget.playerModel,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_upload_outlined),
            activeIcon: Icon(Icons.cloud_upload),
            label: 'Subir',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.queue_music_outlined),
            activeIcon: Icon(Icons.queue_music),
            label: 'Playlists',
          ),
        ],
      ),
    );
  }
}
