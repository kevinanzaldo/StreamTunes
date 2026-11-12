import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/fake/fake_storage_repository.dart';
import 'package:streamtunes/repositories/interfaces/song_repository.dart';
import 'package:streamtunes/repositories/interfaces/storage_repository.dart';
import 'package:streamtunes/services/dispositivo_capacidades.dart';
import 'package:streamtunes/view_models/upload_view_model.dart';

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

  @override
  Future<List<Map<String, dynamic>>> getPlayEventsByBand(String bandId) async =>
      const [];
}

/// Repositorio cuyo `addSong` siempre falla (por ejemplo, error de red o de RLS).
class _ThrowingSongRepository extends _RecordingSongRepository {
  _ThrowingSongRepository([this.error]);

  final Object? error;

  @override
  Future<Song> addSong(Song song, {String? albumId}) async {
    throw error ?? Exception('sin permisos');
  }
}

/// Simula un `StorageRepository` real (no Fake) donde falla la subida de portada.
class _SupabaseLikeThrowingCoverStorage implements StorageRepository {
  @override
  bool get isMock => false;

  @override
  Future<String> uploadAudio({
    required String bandId,
    required String songId,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async => '$bandId/$songId.mp3';

  @override
  Future<String> uploadCover({
    required String bandId,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    throw Exception('bucket covers error 500');
  }

  @override
  String getAudioPublicUrl(String path) =>
      'https://example.supabase.co/storage/v1/object/public/audio/$path';

  @override
  String getCoverPublicUrl(String path) =>
      'https://example.supabase.co/storage/v1/object/public/covers/$path';
}

void _seleccionarAudioValido(
  UploadViewModel vm, {
  Duration? duration = const Duration(minutes: 2),
}) {
  vm.seleccionarArchivoAudio(
    'demo_tema.mp3',
    bytes: Uint8List.fromList([1, 2, 3, 4]),
    duration: duration,
  );
}

void main() {
  test(
    'UploadViewModel: publica a través del SongRepository inyectado',
    () async {
      final repo = _RecordingSongRepository();
      final vm = UploadViewModel(
        songRepository: repo,
        storageRepository: FakeStorageRepository(),
        autoInicializar: false,
      );
      addTearDown(vm.dispose);

      _seleccionarAudioValido(vm);
      final ok = await vm.publicarTema(
        titulo: '  Tema Inyectado  ',
        subirEnSegundoPlano: false,
      );

      expect(ok, isTrue);
      expect(repo.added, hasLength(1));
      expect(repo.added.single.title, 'Tema Inyectado');
      expect(vm.subiendo, isFalse);
      expect(vm.error, isNull);
    },
  );

  test('UploadViewModel: si el repositorio falla informa el error y libera el estado', () async {
    final vm = UploadViewModel(
      songRepository: _ThrowingSongRepository(),
      storageRepository: FakeStorageRepository(),
      autoInicializar: false,
    );
    addTearDown(vm.dispose);

    _seleccionarAudioValido(vm);
    final ok = await vm.publicarTema(
      titulo: 'Tema que falla',
      subirEnSegundoPlano: false,
    );

    expect(ok, isFalse);
    expect(vm.error, contains('Error al subir tema'));
    expect(vm.subiendo, isFalse);
  });

  test(
    'UploadViewModel: no publica dos veces si se toca el botón en simultáneo',
    () async {
      final repo = _RecordingSongRepository();
      final vm = UploadViewModel(
        songRepository: repo,
        storageRepository: FakeStorageRepository(),
        autoInicializar: false,
      );
      addTearDown(vm.dispose);

      _seleccionarAudioValido(vm);
      final resultados = await Future.wait([
        vm.publicarTema(titulo: 'Doble toque', subirEnSegundoPlano: false),
        vm.publicarTema(titulo: 'Doble toque', subirEnSegundoPlano: false),
      ]);

      expect(resultados, equals([true, false]));
      expect(repo.added, hasLength(1));
    },
  );

  test(
    'UploadViewModel: rechaza subir canciones con duración menor a 1 minuto',
    () async {
      final repo = _RecordingSongRepository();
      final vm = UploadViewModel(
        songRepository: repo,
        storageRepository: FakeStorageRepository(),
        autoInicializar: false,
      );
      addTearDown(vm.dispose);

      _seleccionarAudioValido(vm, duration: const Duration(seconds: 45));
      // Intento de publicar tema de 45 segundos (< 60 s)
      final ok = await vm.publicarTema(
        titulo: 'Tema muy corto',
        subirEnSegundoPlano: false,
      );

      expect(ok, isFalse);
      expect(vm.error, contains('al menos 1 minuto'));
      expect(repo.added, isEmpty);

      // Ahora con duración válida de 1 min 20 s (>= 60 s)
      _seleccionarAudioValido(
        vm,
        duration: const Duration(minutes: 1, seconds: 20),
      );
      final okValido = await vm.publicarTema(
        titulo: 'Tema de duración válida',
        subirEnSegundoPlano: false,
      );

      expect(okValido, isTrue);
      expect(repo.added, hasLength(1));
      expect(
        repo.added.single.duration,
        const Duration(minutes: 1, seconds: 20),
      );
    },
  );

  test('UploadViewModel: publicar sin audio devuelve false, setea error y no llama addSong', () async {
    final repo = _RecordingSongRepository();
    final vm = UploadViewModel(
      songRepository: repo,
      storageRepository: FakeStorageRepository(),
      autoInicializar: false,
    );
    addTearDown(vm.dispose);

    final ok = await vm.publicarTema(
      titulo: 'Sin audio seleccionado',
      duracion: const Duration(minutes: 2),
      subirEnSegundoPlano: false,
    );

    expect(ok, isFalse);
    expect(vm.error, 'Elegí un archivo de audio (.mp3, .m4a o .wav).');
    expect(vm.subiendo, isFalse);
    expect(repo.added, isEmpty);
  });

  test(
    'UploadViewModel: audio sin duración legible falla y no inventa 3:20',
    () async {
      final repo = _RecordingSongRepository();
      final vm = UploadViewModel(
        songRepository: repo,
        storageRepository: FakeStorageRepository(),
        autoInicializar: false,
      );
      addTearDown(vm.dispose);

      _seleccionarAudioValido(vm, duration: null);
      final ok = await vm.publicarTema(
        titulo: 'Audio ilegible',
        subirEnSegundoPlano: false,
      );

      expect(ok, isFalse);
      expect(
        vm.error,
        'No pudimos leer la duración del audio, probá con otro archivo.',
      );
      expect(repo.added, isEmpty);
    },
  );

  test(
    'UploadViewModel: guarda el género elegido en lugar de un valor fijo',
    () async {
      final repo = _RecordingSongRepository();
      final vm = UploadViewModel(
        songRepository: repo,
        storageRepository: FakeStorageRepository(),
        autoInicializar: false,
      );
      addTearDown(vm.dispose);

      _seleccionarAudioValido(vm);
      vm.setGenero('Electrónica');
      final ok = await vm.publicarTema(
        titulo: 'Pulso Nocturno',
        subirEnSegundoPlano: false,
      );

      expect(ok, isTrue);
      expect(repo.added.single.genre, 'Electrónica');
    },
  );

  test('UploadViewModel: muestra el error límite de 2 álbumes cuando lo lanza el repositorio', () async {
    final repo = _ThrowingSongRepository(Exception('limite_alcanzado: album'));
    final vm = UploadViewModel(
      songRepository: repo,
      storageRepository: FakeStorageRepository(),
      autoInicializar: false,
    );
    addTearDown(vm.dispose);

    _seleccionarAudioValido(vm);
    final ok = await vm.publicarTema(
      titulo: 'Tercer Álbum',
      album: 'Disco 3',
      subirEnSegundoPlano: false,
    );

    expect(ok, isFalse);
    expect(vm.error, 'Límite de subida alcanzado: máximo 2 álbumes por banda.');
  });

  test('UploadViewModel: si falla portada en Storage real publica sin portada ni data URI y avisa', () async {
    final repo = _RecordingSongRepository();
    final vm = UploadViewModel(
      dispositivoCapacidades: _TestDispositivoCapacidades(
        mockImage: SelectedImageFile(
          name: 'portada.jpg',
          bytes: Uint8List.fromList([255, 216, 255]),
        ),
      ),
      songRepository: repo,
      storageRepository: _SupabaseLikeThrowingCoverStorage(),
      autoInicializar: false,
    );
    addTearDown(vm.dispose);

    _seleccionarAudioValido(vm);
    await vm.seleccionarFotoDeGaleria();
    final ok = await vm.publicarTema(
      titulo: 'Con falla de portada',
      subirEnSegundoPlano: false,
    );

    expect(ok, isTrue);
    expect(repo.added, hasLength(1));
    expect(repo.added.single.coverUrl, isNull);
    expect(vm.avisoPortada, contains('No se pudo subir la portada'));
  });
}

class _TestDispositivoCapacidades extends DispositivoCapacidades {
  _TestDispositivoCapacidades({this.mockImage});
  final SelectedImageFile? mockImage;

  @override
  Future<SelectedImageFile?> seleccionarFotoArchivo() async => mockImage;
}
