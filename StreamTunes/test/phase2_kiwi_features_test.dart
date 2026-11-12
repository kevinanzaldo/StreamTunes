import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/config/app_constants.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/band_event.dart';
import 'package:streamtunes/models/band_photo.dart';
import 'package:streamtunes/models/donation.dart';
import 'package:streamtunes/models/metricas_artista.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_song_repository.dart';
import 'package:streamtunes/repositories/fake/fake_storage_repository.dart';
import 'package:streamtunes/services/dispositivo_capacidades.dart';
import 'package:streamtunes/services/lrc_parser.dart';
import 'package:streamtunes/services/pending_follow_service.dart';
import 'package:streamtunes/view_models/band_public_view_model.dart';
import 'package:streamtunes/view_models/reproductor_view_model.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/view_models/upload_view_model.dart';
import 'package:streamtunes/views/band_public_view.dart';
import 'package:streamtunes/widgets/now_playing_modal.dart';
import 'package:streamtunes/widgets/reproductor_scope.dart';
import 'package:streamtunes/widgets/session_scope.dart';

class _OfflineFollowBandRepo extends FakeBandRepository {
  bool offline = true;

  @override
  Future<void> followBand(String bandId) async {
    if (offline) {
      throw Exception('Sin conexión en el sótano');
    }
    return super.followBand(bandId);
  }
}

class _FailingFirstSongRepo extends FakeSongRepository {
  bool shouldFail = true;

  @override
  Future<Song> addSong(Song song, {String? albumId}) async {
    if (shouldFail) {
      throw Exception('Corte de red temporal');
    }
    return super.addSong(song, albumId: albumId);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('LrcParser parsea marcas temporales y calcula línea activa', () {
    expect(LrcParser.parse(null), isEmpty);
    expect(LrcParser.parse('   '), isEmpty);

    const raw = '[00:05.50] Primera línea\n[00:12.00] Segunda línea';
    final lines = LrcParser.parse(raw);

    expect(lines, hasLength(2));
    expect(lines.first.text, 'Primera línea');
    expect(lines.last.text, 'Segunda línea');
    expect(LrcParser.activeLineIndex(lines, const Duration(seconds: 2)), -1);
    expect(LrcParser.activeLineIndex(lines, const Duration(seconds: 6)), 0);
    expect(LrcParser.activeLineIndex(lines, const Duration(seconds: 15)), 1);
  });

  test(
    'PendingFollowService encola offline y sincroniza al volver la conexión',
    () async {
      final repo = _OfflineFollowBandRepo()..offline = true;
      final pendingService = PendingFollowService();

      final authRepo = FakeAuthRepository();
      final session = SessionViewModel(
        authRepository: authRepo,
        bandRepository: repo,
        pendingFollowService: pendingService,
      );

      // Escaneo QR offline sin mail
      final res = await session.followBandWithQr('artist_1');
      expect(res.followed, isTrue);
      expect(res.queuedOffline, isTrue);
      expect(await pendingService.hasPendingFollow('artist_1'), isTrue);

      // Vuelve la señal
      repo.offline = false;
      final syncedCount = await session.syncPendingFollows();
      expect(syncedCount, 1);
      expect(await pendingService.hasPendingFollow('artist_1'), isFalse);
      expect(await repo.isFollowingBand('artist_1'), isTrue);

      session.dispose();
    },
  );

  test(
    'FakeDonationRepository filtra donaciones pending y refunded del muro',
    () async {
      final repo = FakeDonationRepository();
      await repo.addDonation(
        Donation(
          id: 'd_pending',
          artistId: 'b1',
          artistName: 'Kiwi',
          amount: 1000,
          paymentMethod: 'Pasarela',
          status: DonationStatus.pending,
        ),
      );
      await repo.addDonation(
        Donation(
          id: 'd_refunded',
          artistId: 'b1',
          artistName: 'Kiwi',
          amount: 1000,
          paymentMethod: 'Pasarela',
          status: DonationStatus.refunded,
        ),
      );
      await repo.addDonation(
        Donation(
          id: 'd_approved',
          artistId: 'b1',
          artistName: 'Kiwi',
          amount: 2000,
          paymentMethod: 'Pasarela',
          isPublic: false,
          status: DonationStatus.approved,
        ),
      );

      final wall = await repo.getBandDonations('b1');
      expect(wall, hasLength(1));
      expect(wall.first.id, 'd_approved');
      expect(wall.first.isPublic, isFalse);
      repo.dispose();
    },
  );

  test(
    'UploadViewModel valida formato/tamaño, progreso, LRC y permite reintentar',
    () async {
      final songRepo = _FailingFirstSongRepo();
      final storageRepo = FakeStorageRepository();
      final vm = UploadViewModel(
        dispositivoCapacidades: DispositivoCapacidades(
          forzarTieneCamara: false,
        ),
        songRepository: songRepo,
        storageRepository: storageRepo,
        autoInicializar: false,
      );

      // Formato no permitido
      vm.seleccionarArchivoAudio(
        'virus.exe',
        bytes: Uint8List.fromList([1, 2, 3]),
        duration: const Duration(minutes: 2),
      );
      expect(vm.error, contains('Formato de audio no válido'));

      // Archivo demasiado grande (> kMaxAudioFileSizeBytes)
      vm.seleccionarArchivoAudio(
        'show_gigante.wav',
        bytes: Uint8List.fromList([1, 2, 3]),
        size: kMaxAudioFileSizeBytes + 1024,
        duration: const Duration(minutes: 4),
      );
      expect(vm.error, contains('transcodificación en servidor'));

      // Archivo válido con LRC pero repositorio falla al primer intento
      vm.seleccionarArchivoAudio(
        'tema_kiwi.mp3',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        duration: const Duration(minutes: 3),
      );
      final firstTry = await vm.publicarTema(
        titulo: 'Tema Under',
        lyricsLrc: '[00:05.00] Verso uno',
      );
      expect(firstTry, isFalse);
      expect(vm.puedeReintentar, isTrue);

      // Recupera conexión y reintenta sin perder datos
      songRepo.shouldFail = false;
      final retryOk = await vm.reintentarSubida();
      expect(retryOk, isTrue);
      expect(vm.uploadProgress, 1.0);
      final saved = await songRepo.getSongsByBand('artist_1');
      expect(
        saved.any(
          (s) =>
              s.title == 'Tema Under' && s.lyricsLrc == '[00:05.00] Verso uno',
        ),
        isTrue,
      );

      vm.dispose();
    },
  );

  testWidgets(
    'NowPlayingModal oculta sección LRC si no hay letra y la muestra si existe',
    (tester) async {
      final player = ReproductorViewModel();
      addTearDown(player.dispose);

      final songNoLyrics = Song(
        id: 's_no_lrc',
        title: 'Instrumental',
        artistId: 'b1',
        artistName: 'Kiwi',
        album: 'Sencillo',
        duration: const Duration(minutes: 2),
        genre: 'Rock',
        icon: Icons.music_note,
        gradientColors: const [Colors.green, Colors.black],
        uploadedAt: DateTime(2026, 1, 1),
      );
      player.play(songNoLyrics);

      await tester.pumpWidget(
        MaterialApp(
          home: ReproductorScope(
            reproductor: player,
            child: const Scaffold(body: NowPlayingModal()),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('now_playing_lyrics_toggle')),
        findsNothing,
      );

      final songWithLyrics = songNoLyrics.copyWith(
        lyricsLrc: '[00:00.00] Cantando en el sótano',
      );
      player.play(songWithLyrics);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('now_playing_lyrics_toggle')),
        findsOneWidget,
      );
      expect(find.text('Cantando en el sótano'), findsOneWidget);
      player.pause();
    },
  );

  testWidgets(
    'BandPublicView muestra Top 10, agenda, fotos, merch y banners diferenciados en pantalla grande',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final band = Band(
        id: 'band_kiwi',
        slug: 'kiwi-under',
        name: 'Kiwi Under',
        bio: 'Banda under de sótano.',
        genre: 'Indie',
        location: 'La Plata',
        merchUrl: 'https://kiwi.mitiendanube.com',
        createdBy: 'u1',
        createdAt: DateTime(2026, 1, 1),
      );
      final bandRepo = FakeBandRepository(
        initialBands: [band],
        initialTopFans: {
          'band_kiwi': const [
            OyenteTop(nombre: 'Sofía Pública', minutos: 180, isPublic: true),
            OyenteTop(nombre: 'Privado', minutos: 90, isPublic: false),
          ],
        },
        initialEvents: [
          BandEvent(
            id: 'e1',
            bandId: 'band_kiwi',
            title: 'Recital en el Sótano',
            venue: 'Guajira',
            city: 'La Plata',
            eventDate: DateTime(2026, 5, 20, 22, 0),
          ),
        ],
        initialPhotos: [
          BandPhoto(
            id: 'p1',
            bandId: 'band_kiwi',
            photoUrl: 'https://example.com/show.jpg',
            caption: 'Festival de verano',
            createdAt: DateTime(2026, 2, 1),
          ),
        ],
      );
      final donationRepo = FakeDonationRepository()..setSpendCapActive(true);
      final vm = BandPublicViewModel(
        band: band,
        songRepository: FakeSongRepository(),
        donationRepository: donationRepo,
        bandRepository: bandRepo,
      );
      await vm.load();

      final player = ReproductorViewModel();
      final session = SessionViewModel(
        authRepository: FakeAuthRepository(),
        bandRepository: bandRepo,
      );
      addTearDown(player.dispose);
      addTearDown(session.dispose);
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ReproductorScope(
            reproductor: player,
            child: SessionScope(
              session: session,
              child: BandPublicView(band: band, viewModel: vm),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Modo de cuidado de ancho de banda activo por alta demanda del servidor.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tienda de merch (remeras y vinilos)'), findsOneWidget);
      expect(find.text('Recital en el Sótano'), findsOneWidget);
      expect(find.text('Fotos de shows'), findsOneWidget);
      expect(find.text('Sofía Pública'), findsOneWidget);
      expect(find.text('Fan anónimo'), findsOneWidget);

      // Verificar diálogo de donación muestra tope transaccional distinto y switch anónimo
      await tester.tap(find.text('Apoyar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('max_donation_banner')), findsOneWidget);
      expect(
        find.textContaining(
          'Límite máximo por transacción para seguridad del donante',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('donate_anonymous_switch')),
        findsOneWidget,
      );
    },
  );
}
