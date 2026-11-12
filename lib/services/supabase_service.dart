import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Punto único de acceso al cliente de Supabase.
///
/// Solo se inicializa cuando hay credenciales y no se pidió el modo mock
/// (ver `AppConfig.shouldUseMock`). Usa únicamente la clave pública.
class SupabaseService {
  const SupabaseService._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
