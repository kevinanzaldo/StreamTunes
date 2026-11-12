import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/repositories/fake/fake_storage_repository.dart';
import 'package:streamtunes/services/background_upload_service.dart';
import 'package:streamtunes/services/dispositivo_capacidades.dart';
import 'package:streamtunes/view_models/upload_view_model.dart';
import 'package:streamtunes/views/upload_view.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('BackgroundUploadService: mostrarNotificacion devuelve false en plataforma sin soporte', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    expect(BackgroundUploadService.soportaNotificacionesNativas, isFalse);
    final shown = await BackgroundUploadService.mostrarNotificacion(
      titulo: 'Prueba',
      cuerpo: 'Cuerpo de prueba',
    );
    expect(shown, isFalse);

    final scheduled =
        await BackgroundUploadService.programarSubidaEnSegundoPlano(
          songTitle: 'Sencillo Demo',
          albumTitle: 'Álbum Demo',
        );
    expect(scheduled, isFalse);

    final notifSingle = BackgroundUploadService.buildPublicationNotification(
      songTitle: 'Canción Única',
    );
    expect(notifSingle.titulo, 'Tema publicado');
    expect(
      notifSingle.cuerpo,
      '"Canción Única" ya está disponible en StreamTunes.',
    );

    final notifAlbum = BackgroundUploadService.buildPublicationNotification(
      songTitle: 'Track 1',
      albumTitle: 'Primer Disco',
    );
    expect(notifAlbum.titulo, 'Tema publicado');
    expect(
      notifAlbum.cuerpo,
      '"Track 1" (álbum "Primer Disco") ya está disponible en StreamTunes.',
    );
  });

  testWidgets(
    'UploadView muestra SnackBar in-app tras publicar incluso sin notificación nativa',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final vm = UploadViewModel(
          songRepository: FakeSongRepository(),
          storageRepository: FakeStorageRepository(),
          dispositivoCapacidades: DispositivoCapacidades(
            forzarTieneCamara: false,
          ),
          autoInicializar: false,
        );
        addTearDown(vm.dispose);

        vm.seleccionarArchivoAudio(
          'respaldo_web.mp3',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          duration: const Duration(minutes: 2),
        );

        await tester.pumpWidget(MaterialApp(home: UploadView(viewModel: vm)));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Ej: Canción nueva'),
          'Respaldo In-App',
        );
        final submitButton = find.text('Publicar Tema');
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('Tema "Respaldo In-App" publicado con éxito.'),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
