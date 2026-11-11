import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/config/app_constants.dart';
import 'package:streamtunes/repositories/supabase/supabase_donation_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<(HttpServer, SupabaseClient, SupabaseDonationRepository)> _startStub(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    await handler(req);
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
  return (server, client, SupabaseDonationRepository(client));
}

void main() {
  test('SupabaseDonationRepository.getMaxDonationArs lee max_donation_ars desde app_config', () async {
    final (_, _, repo) = await _startStub((req) async {
      req.response.headers.contentType = ContentType.json;
      if (req.uri.path.endsWith('/rest/v1/app_config') && req.method == 'GET') {
        req.response.statusCode = 200;
        req.response.write(jsonEncode({'value': 3500}));
        return;
      }
      req.response.statusCode = 404;
      req.response.write('{}');
    });

    final maxArs = await repo.getMaxDonationArs();
    expect(maxArs, 3500.0);
  });

  test('SupabaseDonationRepository.getMaxDonationArs usa kMaxDonationArs si app_config falla', () async {
    final (_, _, repo) = await _startStub((req) async {
      req.response.headers.contentType = ContentType.json;
      req.response.statusCode = 500;
      req.response.write(jsonEncode({'message': 'error de red'}));
    });

    final maxArs = await repo.getMaxDonationArs();
    expect(maxArs, kMaxDonationArs);
  });
}
