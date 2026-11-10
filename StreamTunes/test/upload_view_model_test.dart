import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/interfaces/song_repository.dart';
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
}

/// Repositorio cuyo `addSong` siempre falla (por ejemplo, error de red o de RLS).
class _ThrowingSongRepository extends _RecordingSongRepository {
  @override
  Future<Song> addSong(Song song, {String? albumId}) async {
    throw Exception('sin permisos');
  }
}

void main() {
  test(
    'UploadViewModel: publica a través del SongRepository inyectado',
    () async {
      final repo = _RecordingSongRepository();
      final vm = UploadViewModel(songRepository: repo, autoInicializar: false);
      addTearDown(vm.dispose);

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
      autoInicializar: false,
    );
    addTearDown(vm.dispose);

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
      final vm = UploadViewModel(songRepository: repo, autoInicializar: false);
      addTearDown(vm.dispose);

      final resultados = await Future.wait([
        vm.publicarTema(titulo: 'Doble toque', subirEnSegundoPlano: false),
        vm.publicarTema(titulo: 'Doble toque', subirEnSegundoPlano: false),
      ]);

      expect(resultados, equals([true, false]));
      expect(repo.added, hasLength(1));
    },
  );
}
