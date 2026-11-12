import 'package:flutter/foundation.dart';

import '../models/band.dart';
import '../repositories/interfaces/auth_repository.dart';
import '../repositories/interfaces/band_repository.dart';
import 'pending_follow_service.dart';

/// Resultado de la resolución de un link QR con `?band=<slug>`.
class QrResolutionResult {
  final Band? band;
  final String? errorMessage;
  final String? followMessage;
  final bool offlineQueued;

  const QrResolutionResult({
    this.band,
    this.errorMessage,
    this.followMessage,
    this.offlineQueued = false,
  });

  bool get isSuccess => band != null;
}

/// Servicio encargado de leer el parámetro de consulta `band` en la URL de arranque,
/// resolver la banda correspondiente y realizar la suscripción anónima del fan
/// (con respaldo offline en `PendingFollowService` si no hay señal).
class QrResolutionService {
  final BandRepository bandRepository;
  final AuthRepository authRepository;
  final PendingFollowService pendingFollowService;
  final Uri? customUri;

  QrResolutionService({
    required this.bandRepository,
    required this.authRepository,
    PendingFollowService? pendingFollowService,
    this.customUri,
  }) : pendingFollowService = pendingFollowService ?? PendingFollowService();

  Uri get _effectiveUri => customUri ?? Uri.base;

  /// Extrae el slug de banda del query parameter `band` (ej: `?band=kiwi`).
  String? extractBandSlug() {
    final slug = _effectiveUri.queryParameters['band'];
    if (slug == null || slug.trim().isEmpty) return null;
    return slug.trim();
  }

  /// Resuelve la banda al arrancar la app desde un link QR.
  /// Si la banda es válida y está aprobada, autentica anónimamente al fan si no tiene
  /// sesión activa y lo suma como seguidor (o lo encola localmente si no hay conexión).
  Future<QrResolutionResult?> resolveStartupBand() async {
    final slug = extractBandSlug();
    if (slug == null) {
      return null;
    }

    try {
      final band = await bandRepository.getBandBySlug(slug);
      if (band == null || !band.isApproved) {
        return const QrResolutionResult(
          errorMessage:
              'La banda que buscás no existe o todavía no fue aprobada.',
        );
      }

      String? followMessage;
      bool offlineQueued = false;

      try {
        final currentUser = await authRepository.restoreSession();
        if (currentUser == null) {
          await authRepository.signInAnonymously();
        }
        await bandRepository.followBand(band.id);
        followMessage = '¡Ya estás siguiendo a ${band.name}!';
      } catch (e) {
        debugPrint('Fallo al seguir banda en vivo (modo offline): $e');
        await pendingFollowService.queueFollow(band.id);
        offlineQueued = true;
        followMessage =
            'Te vamos a anotar como seguidor cuando vuelva la conexión';
      }

      return QrResolutionResult(
        band: band,
        followMessage: followMessage,
        offlineQueued: offlineQueued,
      );
    } catch (e) {
      debugPrint('Error al resolver banda por QR: $e');
      return const QrResolutionResult(
        errorMessage: 'No pudimos cargar la banda. Verificá tu conexión.',
      );
    }
  }
}
