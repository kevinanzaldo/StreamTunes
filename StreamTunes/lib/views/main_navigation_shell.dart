import 'package:flutter/material.dart';

import '../view_models/library_view_model.dart';
import '../view_models/reproductor_view_model.dart';
import '../widgets/player_bar.dart';
import 'home_view.dart';
import 'library_view.dart';
import 'upload_view.dart';

class MainNavigationShell extends StatefulWidget {
  final ReproductorViewModel? playerModel;
  final LibraryViewModel? libraryModel;

  static const double breakpointWidth = 600.0;

  const MainNavigationShell({super.key, this.playerModel, this.libraryModel});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  void _onDestinationSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < MainNavigationShell.breakpointWidth;

    final List<Widget> pages = [
      HomeView(
        playerModel: widget.playerModel,
        libraryModel: widget.libraryModel,
      ),
      UploadView(
        onSongUploaded: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
      LibraryView(
        playerModel: widget.playerModel,
        libraryModel: widget.libraryModel,
      ),
    ];

    if (isCompact) {
      // Disposición móvil: NavigationBar inferior
      return Scaffold(
        body: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: pages),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: PlayerBar(playerModel: widget.playerModel),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.cloud_upload_outlined),
              selectedIcon: Icon(Icons.cloud_upload),
              label: 'Subir',
            ),
            NavigationDestination(
              icon: Icon(Icons.queue_music_outlined),
              selectedIcon: Icon(Icons.queue_music),
              label: 'Playlists',
            ),
          ],
        ),
      );
    }

    // Disposición pantalla ancha (>= 600px): NavigationRail lateral
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Icon(
                Icons.graphic_eq,
                color: Colors.greenAccent,
                size: 32,
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Inicio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.cloud_upload_outlined),
                selectedIcon: Icon(Icons.cloud_upload),
                label: Text('Subir'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.queue_music_outlined),
                selectedIcon: Icon(Icons.queue_music),
                label: Text('Playlists'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(index: _currentIndex, children: pages),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: PlayerBar(playerModel: widget.playerModel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
