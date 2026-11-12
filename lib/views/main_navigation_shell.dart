import 'package:flutter/material.dart';

import '../services/qr_resolution_service.dart';
import '../widgets/player_bar.dart';
import '../widgets/repositories_scope.dart';
import '../widgets/session_scope.dart';
import 'account_view.dart';
import 'band_dashboard_view.dart';
import 'band_public_view.dart';
import 'home_view.dart';
import 'library_view.dart';
import 'upload_view.dart';

enum _NavDestination { home, upload, playlists, bandDashboard, account }

class MainNavigationShell extends StatefulWidget {
  static const double breakpointWidth = 600.0;

  const MainNavigationShell({super.key, this.qrResolutionService});

  final QrResolutionService? qrResolutionService;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  _NavDestination _currentDestination = _NavDestination.home;
  bool _qrChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveStartupQr();
    });
  }

  Future<void> _resolveStartupQr() async {
    if (!mounted || _qrChecked) return;
    _qrChecked = true;

    final repos = RepositoriesScope.of(context);
    final service =
        widget.qrResolutionService ??
        QrResolutionService(
          bandRepository: repos.bands,
          authRepository: repos.auth,
        );

    final result = await service.resolveStartupBand();
    if (!mounted || result == null) return;

    if (!result.isSuccess) {
      if (result.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
      return;
    }

    if (result.followMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.followMessage!),
          backgroundColor: result.offlineQueued
              ? Colors.grey[800]
              : Colors.green[800],
        ),
      );
    }

    if (mounted && result.band != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BandPublicView(band: result.band!)),
      );
    }
  }

  Widget _buildDemoBanner() {
    return Container(
      key: const ValueKey('demo_mode_banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      color: Colors.amber.shade900,
      child: const SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Modo demo: datos de ejemplo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repos = RepositoriesScope.of(context);
    final isUsingMock = repos.isUsingMock;
    final session = SessionScope.maybeOf(context);
    final isLoggedIn = session?.isLoggedIn ?? false;
    final hasBand =
        session != null && session.hasBand && session.activeBand != null;
    final activeBand = session?.activeBand;

    // Regla de navegación:
    // - Visitante sin loguear: solo ve 'Inicio' y 'Cuenta' (no ve Subir ni Playlists hasta iniciar sesión)
    // - Usuario logueado sin banda: ve 'Inicio', 'Playlists' y 'Cuenta' (no ve Subir hasta tener una banda)
    // - Usuario logueado con banda: ve 'Inicio', 'Subir', 'Playlists', 'Mi banda' y 'Cuenta'
    final availableDestinations = <_NavDestination>[
      _NavDestination.home,
      if (isLoggedIn && hasBand) _NavDestination.upload,
      if (isLoggedIn) _NavDestination.playlists,
      if (isLoggedIn && hasBand) _NavDestination.bandDashboard,
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
        body: Column(
          children: [
            if (isUsingMock) _buildDemoBanner(),
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
      body: Column(
        children: [
          if (isUsingMock) _buildDemoBanner(),
          Expanded(
            child: Row(
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
          ),
        ],
      ),
    );
  }
}
