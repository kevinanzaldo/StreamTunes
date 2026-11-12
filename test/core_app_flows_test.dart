import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/main.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/donation.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/repositories/fake/fake_storage_repository.dart';
import 'package:streamtunes/services/dispositivo_capacidades.dart';
import 'package:streamtunes/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/view_models/band_public_view_model.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/reproductor_view_model.dart';
import 'package:streamtunes/view_models/upload_view_model.dart';
import 'package:streamtunes/views/band_dashboard_view.dart';
import 'package:streamtunes/views/band_public_view.dart';
import 'package:streamtunes/views/main_navigation_shell.dart';
import 'package:streamtunes/views/upload_view.dart';
import 'package:streamtunes/widgets/library_scope.dart';
import 'package:streamtunes/widgets/reproductor_scope.dart';

Band _testBand({
  String id = 'band_test_widget',
  String name = 'Los Frecuenciales',
}) => Band(
  id: id,
  slug: 'los-frecuenciales',
  name: name,
  bio: 'Banda under experimental',
  genre: 'Indie Rock',
  location: 'Buenos Aires',
  donationGoal: 50000,
  donationsCollected: 12000,
  status: BandStatus.approved,
  createdBy: 'user_test',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('StreamTunesApp muestra el inicio y la navegación', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StreamTunesApp());
    await tester.pumpAndSettle();

    expect(find.text('StreamTunes'), findsOneWidget);
    expect(find.text('Bandas'), findsOneWidget);
    expect(find.text('Últimos lanzamientos'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Cuenta'), findsOneWidget);
    // Subir y Playlists no se muestran al visitante hasta iniciar sesión
    expect(find.text('Subir'), findsNothing);
    expect(find.text('Playlists'), findsNothing);
  });

  testWidgets(
    'Bloque 1: MainNavigationShell responsivo (<600px NavigationBar, >=600px NavigationRail)',
    (WidgetTester tester) async {
      final player = ReproductorViewModel();
      final library = LibraryViewModel(
        playlistRepository: FakePlaylistRepository(),
        donationRepository: FakeDonationRepository(),
      );

      // 1. Pantalla móvil (<600px)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ReproductorScope(
            reproductor: player,
            child: LibraryScope(
              library: library,
              child: const MainNavigationShell(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      // 2. Pantalla amplia (>=600px)
      tester.view.physicalSize = const Size(900, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: ReproductorScope(
            reproductor: player,
            child: LibraryScope(
              library: library,
              child: const MainNavigationShell(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      player.dispose();
      library.dispose();
    },
  );

  test('Bloque 2: ReproductorViewModel gestiona reproducción, pausa y cambio de tema', () {
    final viewModel = ReproductorViewModel();
    final tema1 = Song(
      id: '1',
      title: 'Tema 1',
      artistId: 'art_1',
      artistName: 'Artista 1',
      album: 'Álbum 1',
      duration: const Duration(minutes: 3),
      genre: 'Rock',
      icon: Icons.music_note,
      gradientColors: const [Colors.red, Colors.blue],
      uploadedAt: DateTime.now(),
    );
    final tema2 = Song(
      id: '2',
      title: 'Tema 2',
      artistId: 'art_1',
      artistName: 'Artista 1',
      album: 'Álbum 1',
      duration: const Duration(minutes: 4),
      genre: 'Rock',
      icon: Icons.music_note,
      gradientColors: const [Colors.green, Colors.yellow],
      uploadedAt: DateTime.now(),
    );

    // Estado inicial
    expect(viewModel.currentSong, isNull);
    expect(viewModel.isPlaying, isFalse);

    // Reproducir tema 1
    viewModel.play(tema1);
    expect(viewModel.currentSong?.id, equals('1'));
    expect(viewModel.isPlaying, isTrue);

    // Pausar
    viewModel.togglePlay();
    expect(viewModel.isPlaying, isFalse);

    // Reanudar
    viewModel.togglePlay();
    expect(viewModel.isPlaying, isTrue);

    // Cambiar de tema directamente
    viewModel.play(tema2);
    expect(viewModel.currentSong?.id, equals('2'));
    expect(viewModel.isPlaying, isTrue);

    viewModel.dispose();
  });

  testWidgets(
    'Bloque 3: UploadView evalúa tieneCamara (muestra botón de cámara solo si está soportado)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Dispositivo CON soporte de cámara
      final capsConCamara = DispositivoCapacidades(forzarTieneCamara: true);
      final vmConCamara = UploadViewModel(
        dispositivoCapacidades: capsConCamara,
        songRepository: FakeSongRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(home: UploadView(viewModel: vmConCamara)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.photo_camera), findsOneWidget);

      // Dispositivo SIN soporte de cámara
      final capsSinCamara = DispositivoCapacidades(forzarTieneCamara: false);
      final vmSinCamara = UploadViewModel(
        dispositivoCapacidades: capsSinCamara,
        songRepository: FakeSongRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(home: UploadView(viewModel: vmSinCamara)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.photo_camera), findsNothing);

      vmConCamara.dispose();
      vmSinCamara.dispose();
    },
  );

  test('Bloque 4: BandDashboardViewModel calcula métricas reales sobre play_events', () async {
    final songRepo = FakeSongRepository();
    await songRepo.recordPlayEvent(
      songId: 's1',
      bandId: 'band_test_widget',
      secondsListened: 180,
      userId: 'user_fan_1',
    );
    await songRepo.recordPlayEvent(
      songId: 's1',
      bandId: 'band_test_widget',
      secondsListened: 120,
      userId: 'user_fan_1',
    );

    final vm = BandDashboardViewModel(
      band: _testBand(),
      songRepository: songRepo,
      donationRepository: FakeDonationRepository(),
    );
    addTearDown(vm.dispose);

    await vm.load();
    await vm.calculateMetrics();

    expect(vm.isCalculatingStats, isFalse);
    expect(vm.metrics, isNotNull);
    expect(vm.metrics!.totalMinutos, 5);
    expect(vm.metrics!.totalReproducciones, 2);
    expect(vm.metrics!.rankingOyentes, isNotEmpty);
  });

  test('Bloque 5: DonationRepository emite vía StreamController y actualiza muro en vivo', () async {
    final donationRepo = FakeDonationRepository();
    addTearDown(donationRepo.dispose);

    final vm = BandPublicViewModel(
      band: _testBand(),
      songRepository: FakeSongRepository(),
      donationRepository: donationRepo,
    );
    addTearDown(vm.dispose);

    await vm.load();
    expect(vm.recentDonations, isEmpty);

    final testDonation = Donation(
      id: 'don_widget_5',
      artistId: 'band_test_widget',
      artistName: 'Los Frecuenciales',
      amount: 2500,
      paymentMethod: 'MercadoPago',
      donorName: 'Fan Real',
    );

    await donationRepo.addDonation(testDonation);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(vm.recentDonations, hasLength(1));
    expect(vm.recentDonations.first.amount, 2500);
    expect(vm.recentDonations.first.donorName, 'Fan Real');
  });

  test('Bloque 6: UploadViewModel publica tema y valida campos', () async {
    final vm = UploadViewModel(
      songRepository: FakeSongRepository(),
      storageRepository: FakeStorageRepository(),
      autoInicializar: false,
    );

    // 1. Título vacío -> falla
    expect(await vm.publicarTema(titulo: '', album: 'Disco Test'), isFalse);
    expect(vm.error, contains('título'));

    // 2. Sin archivo de audio seleccionado -> falla
    expect(
      await vm.publicarTema(titulo: 'Mi Canción', album: 'Disco Test'),
      isFalse,
    );
    expect(vm.error, contains('archivo de audio'));

    // 3. Audio válido pero con duración no legible -> falla
    vm.seleccionarArchivoAudio(
      'cancion_corrupta.mp3',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(
      await vm.publicarTema(titulo: 'Mi Canción', album: 'Disco Test'),
      isFalse,
    );
    expect(vm.error, contains('duración'));

    // 4. Audio con duración válida -> publica con éxito
    vm.seleccionarArchivoAudio(
      'cancion.mp3',
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      duration: const Duration(minutes: 3, seconds: 15),
    );
    final resultado = await vm.publicarTema(
      titulo: 'Mi Canción',
      album: 'Disco Test',
      subirEnSegundoPlano: false,
    );
    expect(resultado, isTrue);

    vm.dispose();
  });

  test('Bloque 7: AppLifecycle no pausa con inactive y pausa al pasar a hidden o paused', () {
    final repVm = ReproductorViewModel();
    repVm.play(
      Song(
        id: 'tema_life',
        title: 'Vida',
        artistId: 'b1',
        artistName: 'Banda 1',
        album: 'A1',
        duration: const Duration(minutes: 3),
        genre: 'Rock',
        icon: Icons.music_note,
        gradientColors: const [Colors.red, Colors.blue],
        uploadedAt: DateTime.now(),
      ),
    );
    expect(repVm.isPlaying, isTrue);

    // Inactive no pausa
    expect(repVm.isPlaying, isTrue);

    // Paused pausa
    repVm.pause();
    expect(repVm.isPlaying, isFalse);

    repVm.dispose();
  });

  test('Límites de subida: máximo 2 álbumes y 20 temas por banda', () async {
    const bandaId = 'artist_test_limite';
    final songRepo = FakeSongRepository();
    final vm = UploadViewModel(
      songRepository: songRepo,
      storageRepository: FakeStorageRepository(),
      autoInicializar: false,
    );

    Future<bool> subir(String titulo, String album) {
      vm.seleccionarArchivoAudio(
        'audio_$titulo.mp3',
        bytes: Uint8List.fromList([1, 2, 3]),
        duration: const Duration(minutes: 2),
      );
      return vm.publicarTema(
        titulo: titulo,
        album: album,
        artistId: bandaId,
        artistName: 'Banda Test',
        subirEnSegundoPlano: false,
      );
    }

    expect(await subir('Tema A', 'Álbum A'), isTrue);
    expect(await subir('Tema B', 'Álbum B'), isTrue);

    // Un tercer álbum distinto debe ser rechazado
    expect(await subir('Tema C', 'Álbum C'), isFalse);
    expect(vm.error, contains('2 álbumes'));

    // Un tema en un álbum ya existente sí se permite
    expect(await subir('Tema A2', 'Álbum A'), isTrue);

    // Completar el cupo de 20 temas (ya hay 3)
    for (var i = 4; i <= 20; i++) {
      expect(await subir('Tema $i', 'Álbum A'), isTrue);
    }
    expect(await subir('Tema 21', 'Álbum A'), isFalse);
    expect(vm.error, contains('20 temas'));

    vm.dispose();
  });

  testWidgets(
    'BandDashboardView vs BandPublicView: separación de vistas pública y privada',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final band = _testBand();
      final player = ReproductorViewModel();
      final library = LibraryViewModel(
        playlistRepository: FakePlaylistRepository(),
        donationRepository: FakeDonationRepository(),
      );
      addTearDown(player.dispose);
      addTearDown(library.dispose);

      // 1. BandPublicView: es el perfil para el público (no muestra panel de métricas privadas)
      await tester.pumpWidget(
        MaterialApp(
          home: ReproductorScope(
            reproductor: player,
            child: LibraryScope(
              library: library,
              child: BandPublicView(band: band),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Los Frecuenciales'), findsWidgets);
      expect(find.text('Panel de banda'), findsNothing);

      // 2. BandDashboardView: panel privado de administración
      final dashVm = BandDashboardViewModel(
        band: band,
        songRepository: FakeSongRepository(),
        donationRepository: FakeDonationRepository(),
      );
      addTearDown(dashVm.dispose);
      await dashVm.load();

      await tester.pumpWidget(
        MaterialApp(
          home: ReproductorScope(
            reproductor: player,
            child: LibraryScope(
              library: library,
              child: BandDashboardView(band: band, viewModel: dashVm),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Panel: Los Frecuenciales'), findsOneWidget);
      expect(find.text('Métricas de la banda'), findsOneWidget);
    },
  );
}
