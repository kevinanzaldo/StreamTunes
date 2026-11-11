import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'repositories/app_repositories.dart';
import 'services/audio_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'view_models/library_view_model.dart';
import 'view_models/reproductor_view_model.dart';
import 'view_models/session_view_model.dart';
import 'views/main_navigation_shell.dart';
import 'widgets/library_scope.dart';
import 'widgets/repositories_scope.dart';
import 'widgets/reproductor_scope.dart';
import 'widgets/session_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Solo se conecta a Supabase si hay credenciales y no se pidió el modo demo
  // (--dart-define=USE_MOCK=true). Sin credenciales la app sigue en modo mock.
  if (!AppConfig.shouldUseMock) {
    await SupabaseService.initialize();
  }
  runApp(const StreamTunesApp());
}

class StreamTunesApp extends StatefulWidget {
  const StreamTunesApp({super.key});

  @override
  State<StreamTunesApp> createState() => _StreamTunesAppState();
}

class _StreamTunesAppState extends State<StreamTunesApp>
    with WidgetsBindingObserver {
  late final AppRepositories _repositories;
  late final ReproductorViewModel _reproductorViewModel;
  late final LibraryViewModel _libraryViewModel;
  late final SessionViewModel _sessionViewModel;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repositories = AppRepositories.create();
    late final ReproductorViewModel repVm;
    final audioService = AudioService(
      onInterruptionPause: () => repVm.pause(),
      onInterruptionResume: () => repVm.resume(),
    );
    repVm = ReproductorViewModel(
      audioService: audioService,
      songRepository: _repositories.songs,
    );
    _reproductorViewModel = repVm;
    _libraryViewModel = LibraryViewModel(
      playlistRepository: _repositories.playlists,
      donationRepository: _repositories.donations,
    );
    _sessionViewModel = SessionViewModel(
      authRepository: _repositories.auth,
      bandRepository: _repositories.bands,
    );
    _sessionViewModel.addListener(_onSessionChanged);
    unawaited(_sessionViewModel.restore());
  }

  /// Las playlists y donaciones son de cada persona: al entrar, salir o
  /// cambiar de cuenta se vuelve a cargar la biblioteca.
  void _onSessionChanged() {
    final userId = _sessionViewModel.profile?.id;
    if (userId == _lastUserId) return;
    _lastUserId = userId;
    unawaited(_libraryViewModel.load());
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
    // Solo pausar al pasar realmente a segundo plano (paused/hidden) en plataformas nativas.
    // `inactive` también se dispara al abrir diálogos o selectores de archivo/cámara, y las
    // llamadas telefónicas las gestiona AudioService vía `audio_session`.
    // En Web (kIsWeb), la música sigue sonando al cambiar de pestaña o minimizar el navegador.
    if (!kIsWeb &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      _reproductorViewModel.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reproductorViewModel.dispose();
    _sessionViewModel.removeListener(_onSessionChanged);
    _libraryViewModel.dispose();
    _sessionViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoriesScope(
      repositories: _repositories,
      child: SessionScope(
        session: _sessionViewModel,
        child: ReproductorScope(
          reproductor: _reproductorViewModel,
          child: LibraryScope(
            library: _libraryViewModel,
            child: MaterialApp(
              title: 'StreamTunes MVP',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              home: const MainNavigationShell(),
            ),
          ),
        ),
      ),
    );
  }
}
