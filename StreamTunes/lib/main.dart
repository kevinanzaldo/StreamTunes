import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'view_models/library_view_model.dart';
import 'view_models/reproductor_view_model.dart';
import 'views/main_navigation_shell.dart';
import 'widgets/library_scope.dart';
import 'widgets/reproductor_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StreamTunesApp());
}

class StreamTunesApp extends StatefulWidget {
  const StreamTunesApp({super.key});

  @override
  State<StreamTunesApp> createState() => _StreamTunesAppState();
}

class _StreamTunesAppState extends State<StreamTunesApp>
    with WidgetsBindingObserver {
  late final ReproductorViewModel _reproductorViewModel;
  late final LibraryViewModel _libraryViewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reproductorViewModel = ReproductorViewModel();
    _libraryViewModel = LibraryViewModel();
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    debugPrint(
      'StreamTunes: Presión de memoria del sistema detectada. Limpiando caché de imágenes...',
    );
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Si la app pasa a estado inactive o paused (ej. entra llamada telefónica), pausar música
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _reproductorViewModel.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reproductorViewModel.dispose();
    _libraryViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReproductorScope(
      reproductor: _reproductorViewModel,
      child: LibraryScope(
        library: _libraryViewModel,
        child: MaterialApp(
          title: 'StreamTunes MVP',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: MainNavigationShell(
            playerModel: _reproductorViewModel,
            libraryModel: _libraryViewModel,
          ),
        ),
      ),
    );
  }
}
