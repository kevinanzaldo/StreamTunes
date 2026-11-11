import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/supabase/supabase_song_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Song _sampleSong({String album = 'Disco Tres', String? coverUrl}) => Song(
  id: '11111111-1111-4111-8111-111111111111',
  title: 'Nuevo Tema',
  artistId: '22222222-2222-4222-8222-222222222222',
  artistName: 'Los Subterráneos',
  album: album,
  duration: const Duration(minutes: 2, seconds: 30),
  genre: 'Rock',
  icon: Icons.music_note,
  gradientColors: const [Color(0xFF1DB954), Color(0xFF191414)],
  audioUrl: '22222222-2222-4222-8222-222222222222/11111111-1111-4111-8111-111111111111.mp3',
  coverUrl: coverUrl,
  uploadedAt: DateTime.utc(2026, 1, 1),
);

Future<(HttpServer, SupabaseClient, SupabaseSongRepository)> _startStubServer(
  Future<void> Function(HttpRequest request, String body) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final body = await utf8.decoder.bind(req).join();
    await handler(req, body);
    await req.response.close();
  });

  final client = SupabaseClient(
    'http://127.0.0.1:${server.port}',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  addTearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });
  return (server, client, SupabaseSongRepository(client));
}

void main() {
  test('SupabaseSongRepository.addSong relanza error de límite de álbumes en lugar de tragarlo', () async {
    var songsInserted = false;
    final (_, _, repo) = await _startStubServer((req, body) async {
      req.response.headers.contentType = ContentType.json;
      if (req.uri.path.endsWith('/rest/v1/albums') && req.method == 'GET') {
        req.response.statusCode = 200;
        req.response.write('null');
        return;
      }
      if (req.uri.path.endsWith('/rest/v1/albums') && req.method == 'POST') {
        req.response.statusCode = 400;
        req.response.write(
          jsonEncode({
            'code': 'P0001',
            'message':
                'Límite de subida alcanzado: máximo 2 álbumes por banda.',
            'details': null,
            'hint': null,
          }),
        );
        return;
      }
      if (req.uri.path.endsWith('/rest/v1/songs')) {
        songsInserted = true;
      }
      req.response.statusCode = 500;
      req.response.write('{}');
    });

    await expectLater(
      () => repo.addSong(_sampleSong(album: 'Álbum 3')),
      throwsA(
        isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('máximo 2 álbumes'),
        ),
      ),
    );
    expect(songsInserted, isFalse);
  });

  test('SupabaseSongRepository.addSong envía id UUID y reintenta sin cover_url solo si falta esa columna', () async {
    final recordedSongPayloads = <Map<String, dynamic>>[];
    final (_, _, repo) = await _startStubServer((req, body) async {
      req.response.headers.contentType = ContentType.json;
      if (req.uri.path.endsWith('/rest/v1/songs') && req.method == 'POST') {
        final payload = jsonDecode(body) as Map<String, dynamic>;
        recordedSongPayloads.add(payload);
        if (payload.containsKey('cover_url')) {
          req.response.statusCode = 400;
          req.response.write(
            jsonEncode({
              'code': 'PGRST204',
              'message': "Could not find the 'cover_url' column of 'songs' in the schema cache",
              'details': null,
              'hint': null,
            }),
          );
          return;
        }
        req.response.statusCode = 201;
        req.response.write(
          jsonEncode({
            'id': payload['id'],
            'band_id': payload['band_id'],
            'album_id': payload['album_id'],
            'title': payload['title'],
            'genre': payload['genre'],
            'audio_path': payload['audio_path'],
            'duration_s': payload['duration_s'],
            'play_count': 0,
            'created_at': '2026-01-01T00:00:00Z',
            'bands': {
              'name': 'Los Subterráneos',
              'status': 'approved',
              'cover_url': null,
            },
            'albums': null,
          }),
        );
        return;
      }
      req.response.statusCode = 404;
      req.response.write('{}');
    });

    final created = await repo.addSong(
      _sampleSong(
        album: '',
        coverUrl: 'https://cdn.streamtunes.test/cover.jpg',
      ),
    );

    expect(recordedSongPayloads, hasLength(2));
    expect(recordedSongPayloads.first['cover_url'], isNotNull);
    expect(recordedSongPayloads.last.containsKey('cover_url'), isFalse);
    expect(
      recordedSongPayloads.last['id'],
      equals('11111111-1111-4111-8111-111111111111'),
    );
    expect(created.id, equals('11111111-1111-4111-8111-111111111111'));
  });

  test('SupabaseSongRepository.addSong no reintenta sin cover_url ante error RLS real', () async {
    var attempts = 0;
    final (_, _, repo) = await _startStubServer((req, body) async {
      req.response.headers.contentType = ContentType.json;
      if (req.uri.path.endsWith('/rest/v1/songs') && req.method == 'POST') {
        attempts++;
        req.response.statusCode = 403;
        req.response.write(
          jsonEncode({
            'code': '42501',
            'message':
                'new row violates row-level security policy for table "songs"',
            'details': null,
            'hint': null,
          }),
        );
        return;
      }
      req.response.statusCode = 404;
      req.response.write('{}');
    });

    await expectLater(
      () => repo.addSong(
        _sampleSong(album: '', coverUrl: 'https://cdn.test/cover.jpg'),
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(attempts, equals(1));
  });
}
