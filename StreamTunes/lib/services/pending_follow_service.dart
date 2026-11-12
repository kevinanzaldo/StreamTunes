import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/interfaces/band_repository.dart';

/// Cola local (offline-first) para guardar acciones de "seguir banda"
/// disparadas al escanear un QR en sótanos/recitales sin señal y sincronizarlas
/// cuando vuelve la conexión.
class PendingFollowService {
  PendingFollowService({SharedPreferences? prefs}) {
    _prefs = prefs;
  }

  static const String _storageKey = 'streamtunes_pending_band_follows_v1';
  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<String>> getPendingFollows() async {
    try {
      final prefs = await _instance();
      return List<String>.from(prefs.getStringList(_storageKey) ?? const []);
    } catch (_) {
      return const [];
    }
  }

  Future<bool> hasPendingFollow(String bandId) async {
    final pending = await getPendingFollows();
    return pending.contains(bandId);
  }

  Future<void> queueFollow(String bandId) async {
    try {
      final prefs = await _instance();
      final current = List<String>.from(
        prefs.getStringList(_storageKey) ?? const [],
      );
      if (!current.contains(bandId)) {
        current.add(bandId);
        await prefs.setStringList(_storageKey, current);
      }
    } catch (_) {}
  }

  Future<void> removePendingFollow(String bandId) async {
    try {
      final prefs = await _instance();
      final current = List<String>.from(
        prefs.getStringList(_storageKey) ?? const [],
      );
      if (current.remove(bandId)) {
        await prefs.setStringList(_storageKey, current);
      }
    } catch (_) {}
  }

  /// Intenta sincronizar los seguimientos pendientes contra Supabase.
  /// Devuelve los IDs que se pudieron sincronizar exitosamente.
  Future<List<String>> syncPendingFollows(BandRepository repository) async {
    final pending = await getPendingFollows();
    if (pending.isEmpty) return const [];

    final synced = <String>[];
    for (final bandId in pending) {
      try {
        await repository.followBand(bandId);
        await removePendingFollow(bandId);
        synced.add(bandId);
      } catch (_) {
        // Si sigue sin señal, permanece en cola para el próximo intento.
      }
    }
    return synced;
  }
}
