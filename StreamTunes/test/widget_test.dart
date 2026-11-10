import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/mock_data.dart';
import 'package:streamtunes/main.dart';
import 'package:streamtunes/models/artist.dart';
import 'package:streamtunes/models/donation.dart';
import 'package:streamtunes/services/dispositivo_capacidades.dart';
import 'package:streamtunes/services/donaciones_service.dart';
import 'package:streamtunes/view_models/artist_detail_view_model.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/reproductor_view_model.dart';
import 'package:streamtunes/view_models/upload_view_model.dart';
import 'package:streamtunes/views/artist_detail_view.dart';
import 'package:streamtunes/views/main_navigation_shell.dart';
import 'package:streamtunes/views/upload_view.dart';
import 'package:streamtunes/widgets/library_scope.dart';
import 'package:streamtunes/widgets/reproductor_scope.dart';

void main() {
  testWidgets('StreamTunesApp muestra el inicio y la navegación', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StreamTunesApp());
    await tester.pumpAndSettle();

    expect(find.text('StreamTunes'), findsOneWidget);
    expect(find.text('Bandas'), findsOneWidget);
    expect(find.text('Últimos lanzamientos'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Subir'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
  });

  testWidgets(
    'Bloque 1: MainNavigationShell responsivo (<600px NavigationBar, >=600px NavigationRail)',
    (WidgetTester tester) async {
      final player = ReproductorViewModel();
      final library = LibraryViewModel();

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

      // 2. Pantalla escritorio/web (>=600px)
      tester.view.physicalSize = const Size(1024, 768);
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
    final player = ReproductorViewModel();
    final song1 = MockData.songs[0];
    final song2 = MockData.songs[1];

    expect(player.hasSong, isFalse);
    expect(player.isPlaying, isFalse);

    // Play
    player.play(song1);
    expect(player.hasSong, isTrue);
    expect(player.currentSong?.id, equals(song1.id));
    expect(player.isPlaying, isTrue);

    // Pause
    player.pause();
    expect(player.isPlaying, isFalse);

    // Resume / togglePlay
    player.togglePlay();
    expect(player.isPlaying, isTrue);

    // Cambiar tema
    player.cambiarTema(song2);
    expect(player.currentSong?.id, equals(song2.id));
    expect(player.isPlaying, isTrue);

    player.dispose();
  });

  testWidgets(
    'Bloque 3: UploadView evalúa tieneCamara (muestra botón de cámara solo si está soportado)',
    (WidgetTester tester) async {
      // Caso A: Dispositivo con cámara
      final capConCamara = DispositivoCapacidades(forzarTieneCamara: true);
      final vmConCamara = UploadViewModel(
        dispositivoCapacidades: capConCamara,
        autoInicializar: false,
      );
      await vmConCamara.inicializarCapacidades();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadView(
              key: const ValueKey('con_camara'),
              viewModel: vmConCamara,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tomar con cámara'), findsOneWidget);
      expect(find.text('Seleccionar de galería'), findsOneWidget);

      // Caso B: Dispositivo sin cámara (ej. PC web)
      final capSinCamara = DispositivoCapacidades(forzarTieneCamara: false);
      final vmSinCamara = UploadViewModel(
        dispositivoCapacidades: capSinCamara,
        autoInicializar: false,
      );
      await vmSinCamara.inicializarCapacidades();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadView(
              key: const ValueKey('sin_camara'),
              viewModel: vmSinCamara,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tomar con cámara'), findsNothing);
      expect(find.text('Seleccionar de galería'), findsOneWidget);

      vmConCamara.dispose();
      vmSinCamara.dispose();
    },
  );

  test('Bloque 4: ArtistDetailViewModel calcula 50.000 registros pesados con Isolate.run', () async {
    final artist = MockData.artists.first;
    final viewModel = ArtistDetailViewModel(
      artist: artist,
      autoEscucharDonaciones: false,
    );

    expect(viewModel.calculandoEstadisticas, isFalse);
    expect(viewModel.totalMinutosEscuchados, isNull);

    await viewModel.calcularEstadisticasIsolate();

    expect(viewModel.calculandoEstadisticas, isFalse);
    expect(viewModel.totalMinutosEscuchados, isNotNull);
    expect(viewModel.totalMinutosEscuchados!, greaterThan(0));
    expect(viewModel.errorEstadisticas, isNull);

    viewModel.dispose();
  });

  test('Bloque 5: DonacionesService emite vía stream y ArtistDetailViewModel actualiza estado y cancela en dispose', () async {
    final artist = MockData.artists.first;
    final donacionesService = DonacionesService();
    final viewModel = ArtistDetailViewModel(
      artist: artist,
      donacionesService: donacionesService,
      autoEscucharDonaciones: true,
    );

    final inicialDonaciones = artist.donationsCollected;

    // Emitir donación simulada
    final testDonation = Donation(
      id: 'test_don_1',
      artistId: artist.id,
      artistName: artist.name,
      amount: 2500.0,
      message: '¡Prueba unitaria de donación en vivo!',
      paymentMethod: 'TestPay',
      timestamp: DateTime.now(),
    );

    donacionesService.emitirDonacion(testDonation);
    // Esperar microtask del stream
    await Future.delayed(const Duration(milliseconds: 50));

    expect(viewModel.mostrarAlertaDonacion, isTrue);
    expect(viewModel.ultimaDonacion?.id, equals('test_don_1'));
    expect(artist.donationsCollected, equals(inicialDonaciones + 2500.0));

    viewModel.ocultarAlertaDonacion();
    expect(viewModel.mostrarAlertaDonacion, isFalse);

    // Cancelación limpia al liberar recursos
    viewModel.dispose();
  });

  test('Bloque 6: UploadViewModel publica tema y valida campos', () async {
    final vm = UploadViewModel(autoInicializar: false);

    // Sin título debe fallar
    final resultVacio = await vm.publicarTema(titulo: '');
    expect(resultVacio, isFalse);
    expect(vm.error, contains('Ingresa el título'));

    // Con título debe publicar y limpiar
    final resultExito = await vm.publicarTema(
      titulo: 'Tema Test de Banda',
      album: 'Álbum Test',
      subirEnSegundoPlano: false,
    );
    expect(resultExito, isTrue);
    expect(vm.mensajeExito, isNotNull);
    expect(MockData.songs.first.title, equals('Tema Test de Banda'));

    vm.dispose();
  });

  testWidgets(
    'Bloque 7: AppLifecycle pausa la música al pasar a inactive o paused',
    (WidgetTester tester) async {
      await tester.pumpWidget(const StreamTunesApp());
      await tester.pumpAndSettle();

      final reproductorScope = tester
          .element(find.byType(MainNavigationShell))
          .dependOnInheritedWidgetOfExactType<ReproductorScope>();
      final player = reproductorScope!.notifier!;

      player.play(MockData.songs.first);
      expect(player.isPlaying, isTrue);

      // Simular que el sistema notifica una llamada entrante (inactive)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(player.isPlaying, isFalse);

      // Simular reanudación y posterior pausa del sistema
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      player.resume();
      expect(player.isPlaying, isTrue);

      // Transición válida: resumed -> inactive -> hidden -> paused
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(player.isPlaying, isFalse);
    },
  );

  test('Límites de subida: máximo 2 álbumes y 20 temas por banda', () async {
    const bandaId = 'artist_test_limite';
    addTearDown(() => MockData.songs.removeWhere((s) => s.artistId == bandaId));
    final vm = UploadViewModel(autoInicializar: false);

    Future<bool> subir(String titulo, String album) => vm.publicarTema(
      titulo: titulo,
      album: album,
      artistId: bandaId,
      artistName: 'Banda Test',
      subirEnSegundoPlano: false,
    );

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

  testWidgets('Estadísticas privadas: solo las ve el dueño del perfil', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = ReproductorViewModel();
    final library = LibraryViewModel();
    addTearDown(player.dispose);
    addTearDown(library.dispose);

    Future<void> mostrarPerfil(Artist artist, {bool? esDueno}) async {
      final vm = ArtistDetailViewModel(
        artist: artist,
        autoEscucharDonaciones: false,
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ReproductorScope(
            reproductor: player,
            child: LibraryScope(
              library: library,
              child: ArtistDetailView(
                key: ValueKey('${artist.id}_$esDueno'),
                artist: artist,
                viewModel: vm,
                esDuenoDelPerfil: esDueno,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const panelEstadisticas = 'Métricas en Segundo Plano (Isolate)';

    // Artista logueado (simulado): ve sus estadísticas
    await mostrarPerfil(MockData.artists[0]);
    expect(find.text(panelEstadisticas), findsOneWidget);

    // Perfil de otra banda: las estadísticas quedan ocultas
    await mostrarPerfil(MockData.artists[1]);
    expect(find.text(panelEstadisticas), findsNothing);

    // El flag explícito tiene prioridad
    await mostrarPerfil(MockData.artists[1], esDueno: true);
    expect(find.text(panelEstadisticas), findsOneWidget);
  });
}
