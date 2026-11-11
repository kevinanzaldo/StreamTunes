import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/mock_data.dart';
import 'package:streamtunes/main.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/fake/fake_auth_repository.dart';
import 'package:streamtunes/repositories/fake/fake_band_repository.dart';
import 'package:streamtunes/repositories/fake/fake_donation_repository.dart';
import 'package:streamtunes/repositories/fake/fake_playlist_repository.dart';
import 'package:streamtunes/repositories/fake/fake_storage_repository.dart';
import 'package:streamtunes/repositories/interfaces/song_repository.dart';
import 'package:streamtunes/services/dispositivo_capacidades.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/reproductor_view_model.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/view_models/upload_view_model.dart';
import 'package:streamtunes/views/library_view.dart';
import 'package:streamtunes/views/upload_view.dart';
import 'package:streamtunes/widgets/library_scope.dart';
import 'package:streamtunes/widgets/reproductor_scope.dart';
import 'package:streamtunes/widgets/session_scope.dart';
import 'package:streamtunes/widgets/song_tile.dart';

const _ana = 'ana@streamtunes.test';
const _caro = 'caro@streamtunes.test';
const _pass = FakeAuthRepository.demoPassword;

/// Repositorio en memoria que registra lo que se publica.
class _RecordingSongRepository implements SongRepository {
  final List<Song> added = [];

  @override
  Future<List<Song>> getLatestSongs({int limit = 50}) async => const [];

  @override
  Future<List<Song>> getSongsByBand(String bandId) async => const [];

  @override
  Future<Song> addSong(Song song, {String? albumId}) async {
    added.add(song);
    return song;
  }

  @override
  Future<void> recordPlayEvent({
    required String songId,
    required String bandId,
    required int secondsListened,
    String? userId,
  }) async {}
}

/// Sesión de visitante (ya restaurada). Quien la necesita puede iniciar sesión.
Future<SessionViewModel> _crearSesion() async {
  final session = SessionViewModel(
    authRepository: FakeAuthRepository(),
    bandRepository: FakeBandRepository(),
  );
  addTearDown(session.dispose);
  await session.restore();
  return session;
}

Future<UploadViewModel> _crearUploadVm({SongRepository? songs}) async {
  final vm = UploadViewModel(
    dispositivoCapacidades: DispositivoCapacidades(forzarTieneCamara: false),
    songRepository: songs,
    storageRepository: FakeStorageRepository(),
    autoInicializar: false,
  );
  addTearDown(vm.dispose);
  await vm.inicializarCapacidades();
  return vm;
}

/// Monta [home] con los mismos scopes que `main.dart` (la sesión por encima del
/// `MaterialApp`, así también la ven las pantallas que se abren con `push`).
Future<void> _montar(
  WidgetTester tester,
  SessionViewModel session,
  Widget home,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final player = ReproductorViewModel();
  final library = LibraryViewModel(
    playlistRepository: FakePlaylistRepository(),
    donationRepository: FakeDonationRepository(),
    autoCargar: false,
  );
  addTearDown(player.dispose);
  addTearDown(library.dispose);
  await library.load();

  await tester.pumpWidget(
    SessionScope(
      session: session,
      child: ReproductorScope(
        reproductor: player,
        child: LibraryScope(
          library: library,
          child: MaterialApp(home: home),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Subir: un visitante ve el ingreso y no el formulario', (
    WidgetTester tester,
  ) async {
    final session = await _crearSesion();
    final vm = await _crearUploadVm();

    await _montar(tester, session, UploadView(viewModel: vm));

    expect(
      find.text('Ingresá con tu cuenta para subir la música de tu banda.'),
      findsOneWidget,
    );
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Publicar Tema'), findsNothing);
  });

  testWidgets(
    'Subir: al iniciar sesión con una banda aprobada aparece el formulario',
    (WidgetTester tester) async {
      final session = await _crearSesion();
      final vm = await _crearUploadVm();
      await _montar(tester, session, UploadView(viewModel: vm));

      await session.signIn(email: _ana, password: _pass);
      await tester.pumpAndSettle();

      expect(find.text('Entrar'), findsNothing);
      expect(find.text('Publicar Tema'), findsOneWidget);
      expect(
        find.text('Publicás como ${MockData.artists.first.name}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Subir: sin banda ofrece crearla', (WidgetTester tester) async {
    final session = await _crearSesion();
    await session.signIn(email: _caro, password: _pass);
    final vm = await _crearUploadVm();
    await _montar(tester, session, UploadView(viewModel: vm));

    expect(find.text('Subí tu música con una banda'), findsOneWidget);
    expect(find.text('Publicar Tema'), findsNothing);

    await tester.tap(find.text('Crear mi banda'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva banda'), findsOneWidget);
  });

  testWidgets(
    'Subir: con la banda pendiente avisa que todavía no puede publicar',
    (WidgetTester tester) async {
      final session = await _crearSesion();
      await session.signIn(email: _caro, password: _pass);
      await session.createBand(name: 'Los Nuevos');
      final vm = await _crearUploadVm();
      await _montar(tester, session, UploadView(viewModel: vm));

      expect(find.textContaining('todavía no está aprobada'), findsOneWidget);
      expect(find.text('Actualizar estado'), findsOneWidget);
      expect(find.text('Publicar Tema'), findsNothing);
    },
  );

  testWidgets('Subir: publica el tema con la banda activa de la sesión', (
    WidgetTester tester,
  ) async {
    final session = await _crearSesion();
    await session.signIn(email: _ana, password: _pass);
    final repo = _RecordingSongRepository();
    final vm = await _crearUploadVm(songs: repo);
    await _montar(tester, session, UploadView(viewModel: vm));

    // Seleccionar audio válido para habilitar la publicación.
    vm.seleccionarArchivoAudio(
      'tema_ana.mp3',
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      duration: const Duration(minutes: 2),
    );
    // Sin segundo plano: en el test no hay Workmanager.
    await tester.tap(find.byType(SwitchListTile));
    await tester.enterText(find.byType(TextField).first, 'Tema de Ana');
    await tester.tap(find.text('Publicar Tema'));
    await tester.pumpAndSettle();

    expect(repo.added, hasLength(1));
    expect(repo.added.single.title, 'Tema de Ana');
    expect(repo.added.single.artistId, MockData.artists.first.id);
    expect(repo.added.single.artistName, MockData.artists.first.name);
  });

  testWidgets(
    'Playlists: un visitante ve el ingreso y al entrar ve su biblioteca',
    (WidgetTester tester) async {
      final session = await _crearSesion();
      await _montar(tester, session, const LibraryView());

      expect(
        find.text('Ingresá para armar tus playlists y ver tus donaciones.'),
        findsOneWidget,
      );
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);

      await session.signIn(email: _ana, password: _pass);
      await tester.pumpAndSettle();

      expect(find.text('Entrar'), findsNothing);
      expect(find.byType(ExpansionTile), findsWidgets);
    },
  );

  testWidgets(
    'SongTile: sin sesión avisa que hay que iniciar sesión para guardar',
    (WidgetTester tester) async {
      final session = await _crearSesion();
      await _montar(
        tester,
        session,
        Scaffold(body: SongTile(song: MockData.songs.first)),
      );

      await tester.tap(find.byIcon(Icons.playlist_add));
      await tester.pump();

      expect(
        find.textContaining('Iniciá sesión en la pestaña Cuenta'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'StreamTunesApp: entrar por Cuenta habilita y muestra Playlists',
    (WidgetTester tester) async {
      await tester.pumpWidget(const StreamTunesApp());
      await tester.pumpAndSettle();

      // Al no estar autenticado, Playlists no se muestra en navegación
      expect(find.text('Playlists'), findsNothing);

      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('login_email')), _ana);
      await tester.enterText(
        find.byKey(const ValueKey('login_password')),
        _pass,
      );
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Quiroga'), findsOneWidget);

      expect(find.text('Playlists'), findsOneWidget);
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsWidgets);
    },
  );
}
