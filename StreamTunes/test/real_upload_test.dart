import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/repositories/fake/fake_storage_repository.dart';
import 'package:streamtunes/services/dispositivo_capacidades.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/view_models/upload_view_model.dart';
import 'package:streamtunes/views/upload_view.dart';
import 'package:streamtunes/widgets/session_scope.dart';

void main() {
  late FakeSongRepository songRepo;
  late FakeStorageRepository storageRepo;
  late DispositivoCapacidades capacidades;

  setUp(() {
    songRepo = FakeSongRepository();
    storageRepo = FakeStorageRepository();
    capacidades = DispositivoCapacidades(
      audioPickerOverride: () async => SelectedAudioFile(
        name: 'mi_tema_estudio.mp3',
        size: 3 * 1024 * 1024,
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
      ),
    );
  });

  test(
    'UploadViewModel: cargarCupos obtiene conteo de temas y álbumes',
    () async {
      final vm = UploadViewModel(
        songRepository: songRepo,
        storageRepository: storageRepo,
        dispositivoCapacidades: capacidades,
        autoInicializar: false,
      );

      await vm.cargarCupos('artist_1');
      expect(vm.songCount, greaterThan(0));
      expect(vm.albumCount, greaterThan(0));
      expect(vm.hasReachedSongLimit, isFalse);

      vm.dispose();
    },
  );

  test(
    'UploadViewModel: seleccionarAudio carga el archivo con nombre y bytes',
    () async {
      final vm = UploadViewModel(
        songRepository: songRepo,
        storageRepository: storageRepo,
        dispositivoCapacidades: capacidades,
        autoInicializar: false,
      );

      expect(vm.tieneAudio, isFalse);
      await vm.seleccionarAudio();

      expect(vm.tieneAudio, isTrue);
      expect(vm.nombreArchivoAudio, 'mi_tema_estudio.mp3');
      expect(vm.selectedAudio?.formattedSize, '3.0 MB');

      vm.dispose();
    },
  );

  test(
    'UploadViewModel: publicarTema sube el archivo a StorageRepository',
    () async {
      final vm = UploadViewModel(
        songRepository: songRepo,
        storageRepository: storageRepo,
        dispositivoCapacidades: capacidades,
        autoInicializar: false,
      );

      await vm.seleccionarAudio();
      final ok = await vm.publicarTema(
        titulo: 'Nuevo Hit Subterráneo',
        album: 'Álbum Uno',
        artistId: 'artist_1',
        artistName: 'Los Subterráneos',
        subirEnSegundoPlano: false,
      );

      expect(ok, isTrue);
      expect(storageRepo.uploadedAudio, isNotEmpty);
      final uploadedPath = storageRepo.uploadedAudio.keys.first;
      expect(uploadedPath, startsWith('artist_1/song_'));
      expect(uploadedPath, endsWith('.mp3'));

      vm.dispose();
    },
  );

  testWidgets(
    'UploadView: muestra cupo de temas y estado de audio seleccionado',
    (WidgetTester tester) async {
      final authRepo = FakeAuthRepository();
      final bandRepo = FakeBandRepository();
      final session = SessionViewModel(
        authRepository: authRepo,
        bandRepository: bandRepo,
      );
      await session.restore();
      await session.signIn(
        email: 'ana@streamtunes.test',
        password: FakeAuthRepository.demoPassword,
      );

      final vm = UploadViewModel(
        songRepository: songRepo,
        storageRepository: storageRepo,
        dispositivoCapacidades: capacidades,
        autoInicializar: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SessionScope(
            session: session,
            child: UploadView(viewModel: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Muestra que publica como Los Subterráneos
      expect(find.text('Publicás como Los Subterráneos'), findsOneWidget);

      // Muestra el botón para seleccionar audio
      expect(find.text('Seleccionar MP3'), findsOneWidget);

      // Tocar botón de seleccionar MP3
      await tester.tap(find.text('Seleccionar MP3'));
      await tester.pumpAndSettle();

      // Debe mostrar el audio seleccionado con su tamaño
      expect(find.textContaining('mi_tema_estudio.mp3'), findsWidgets);
      expect(find.textContaining('3.0 MB'), findsWidgets);

      session.dispose();
      vm.dispose();
    },
  );
}
