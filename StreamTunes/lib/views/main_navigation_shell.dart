import 'package:flutter/material.dart';

import '../widgets/player_bar.dart';
import '../widgets/session_scope.dart';
import 'account_view.dart';
import 'band_dashboard_view.dart';
import 'home_view.dart';
import 'library_view.dart';
import 'upload_view.dart';

enum _NavDestination { home, upload, playlists, bandDashboard, account }

class MainNavigationShell extends StatefulWidget {
  static const double breakpointWidth = 600.0;

  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  _NavDestination _currentDestination = _NavDestination.home;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.maybeOf(context);
    final hasBand =
        session != null && session.hasBand && session.activeBand != null;
    final activeBand = session?.activeBand;

    final availableDestinations = <_NavDestination>[
      _NavDestination.home,
      _NavDestination.upload,
      _NavDestination.playlists,
      if (hasBand) _NavDestination.bandDashboard,
      _NavDestination.account,
    ];

    var currentIndex = availableDestinations.indexOf(_currentDestination);
    if (currentIndex == -1) {
      _currentDestination = _NavDestination.home;
      currentIndex = 0;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < MainNavigationShell.breakpointWidth;

    final List<Widget> pages = availableDestinations.map<Widget>((dest) {
      switch (dest) {
        case _NavDestination.home:
          return const HomeView();
        case _NavDestination.upload:
          return UploadView(
            onSongUploaded: () {
              setState(() {
                _currentDestination = _NavDestination.home;
              });
            },
          );
        case _NavDestination.playlists:
          return const LibraryView();
        case _NavDestination.bandDashboard:
          return KeyedSubtree(
            key: ValueKey('band_dashboard_${activeBand!.id}'),
            child: BandDashboardView(band: activeBand),
          );
        case _NavDestination.account:
          return const AccountView();
      }
    }).toList();

    void onDestinationSelected(int index) {
      if (index >= 0 && index < availableDestinations.length) {
        final selected = availableDestinations[index];
        if (_currentDestination != selected) {
          setState(() {
            _currentDestination = selected;
          });
        }
      }
    }

    if (isCompact) {
      // Disposición móvil: NavigationBar inferior
      return Scaffold(
        body: Stack(
          children: [
            IndexedStack(index: currentIndex, children: pages),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: PlayerBar()),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: availableDestinations.map((dest) {
            switch (dest) {
              case _NavDestination.home:
                return const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Inicio',
                );
              case _NavDestination.upload:
                return const NavigationDestination(
                  icon: Icon(Icons.cloud_upload_outlined),
                  selectedIcon: Icon(Icons.cloud_upload),
                  label: 'Subir',
                );
              case _NavDestination.playlists:
                return const NavigationDestination(
                  icon: Icon(Icons.queue_music_outlined),
                  selectedIcon: Icon(Icons.queue_music),
                  label: 'Playlists',
                );
              case _NavDestination.bandDashboard:
                return const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Mi banda',
                );
              case _NavDestination.account:
                return const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Cuenta',
                );
            }
          }).toList(),
        ),
      );
    }

    // Disposición pantalla ancha (>= 600px): NavigationRail lateral
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Icon(
                Icons.graphic_eq,
                color: Colors.greenAccent,
                size: 32,
              ),
            ),
            destinations: availableDestinations.map((dest) {
              switch (dest) {
                case _NavDestination.home:
                  return const NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Inicio'),
                  );
                case _NavDestination.upload:
                  return const NavigationRailDestination(
                    icon: Icon(Icons.cloud_upload_outlined),
                    selectedIcon: Icon(Icons.cloud_upload),
                    label: Text('Subir'),
                  );
                case _NavDestination.playlists:
                  return const NavigationRailDestination(
                    icon: Icon(Icons.queue_music_outlined),
                    selectedIcon: Icon(Icons.queue_music),
                    label: Text('Playlists'),
                  );
                case _NavDestination.bandDashboard:
                  return const NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: Text('Mi banda'),
                  );
                case _NavDestination.account:
                  return const NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('Cuenta'),
                  );
              }
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(index: currentIndex, children: pages),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(top: false, child: PlayerBar()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
