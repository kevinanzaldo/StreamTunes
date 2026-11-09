import 'package:changenotifier_ejercicio/data/mock_data.dart';
import 'package:changenotifier_ejercicio/main.dart';
import 'package:changenotifier_ejercicio/models/donation.dart';
import 'package:changenotifier_ejercicio/services/dispositivo_capacidades.dart';
import 'package:changenotifier_ejercicio/services/donaciones_service.dart';
import 'package:changenotifier_ejercicio/view_models/artist_detail_view_model.dart';
import 'package:changenotifier_ejercicio/view_models/library_view_model.dart';
import 'package:changenotifier_ejercicio/view_models/reproductor_view_model.dart';
import 'package:changenotifier_ejercicio/view_models/upload_view_model.dart';
import 'package:changenotifier_ejercicio/views/main_navigation_shell.dart';
import 'package:changenotifier_ejercicio/views/upload_view.dart';
import 'package:changenotifier_ejercicio/widgets/library_scope.dart';
import 'package:changenotifier_ejercicio/widgets/reproductor_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
