import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

const String backgroundUploadTaskKey = 'streamtunes_background_album_upload';

/// Función top-level requerida por Workmanager para el aislamiento del isolate en segundo plano.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (task == backgroundUploadTaskKey ||
        task == Workmanager.iOSBackgroundTask) {
      // Inicializar el plugin de notificaciones dentro de este isolate independiente (Criterio E2)
      await BackgroundUploadService.inicializarEnIsolate();

      // Simular espera de 5 segundos de subida pesada en segundo plano (Bloque 6)
      await Future.delayed(const Duration(seconds: 5));

      final albumTitle = inputData?['albumTitle'] as String? ?? 'Álbum Indie';

      // Disparar notificación local usando flutter_local_notifications
      await BackgroundUploadService.mostrarNotificacion(
        titulo: '¡Álbum publicado con éxito!',
        cuerpo: 'Tu álbum "$albumTitle" ya está disponible en StreamTunes.',
      );
    }
    return Future.value(true);
  });
}

class BackgroundUploadService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// En Web y escritorio Linux/Windows el plugin de notificaciones nativas no está
  /// configurado; evitar invocarlo previene errores silenciosos.
  static bool get soportaNotificacionesNativas {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Workmanager solo corre en Android e iOS.
  static bool get soportaSegundoPlano {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @visibleForTesting
  static void resetParaTests() {
    _initialized = false;
  }

  /// Inicialización para el isolate secundario de Workmanager.
  static Future<void> inicializarEnIsolate() async {
    if (!soportaNotificacionesNativas) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    try {
      await _notificationsPlugin.initialize(settings: initializationSettings);
    } catch (e) {
      debugPrint('Isolate Notifications init: $e');
    }
  }

  static Future<void> inicializar() async {
    if (_initialized) return;

    if (!soportaNotificacionesNativas) {
      debugPrint(
        'Notificaciones nativas omitidas en esta plataforma '
        '(web=$kIsWeb, platform=$defaultTargetPlatform).',
      );
      _initialized = true;
      return;
    }

    if (soportaSegundoPlano) {
      try {
        await Workmanager().initialize(callbackDispatcher);
      } catch (e) {
        debugPrint('Workmanager init: $e');
      }
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    try {
      await _notificationsPlugin.initialize(settings: initializationSettings);
    } catch (e) {
      debugPrint('Notifications init: $e');
    }

    // Android 13+ exige pedir el permiso de notificaciones en tiempo de ejecución
    try {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Permiso de notificaciones: $e');
    }

    _initialized = true;
  }

  /// Muestra una notificación local nativa cuando la plataforma lo soporta.
  /// Devuelve `true` si el plugin mostró la notificación, o `false` en Web /
  /// plataformas no soportadas o ante error (registrado con `debugPrint`).
  static Future<bool> mostrarNotificacion({
    required String titulo,
    required String cuerpo,
  }) async {
    if (!soportaNotificacionesNativas) {
      debugPrint(
        'Notificación local omitida: plataforma no soportada '
        '(web=$kIsWeb, platform=$defaultTargetPlatform).',
      );
      return false;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'streamtunes_uploads_channel',
          'Subidas de StreamTunes',
          channelDescription: 'Notificaciones sobre subida de álbumes y pistas',
          importance: Importance.max,
          priority: Priority.high,
        );
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails();
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: DateTime.now().millisecond,
        title: titulo,
        body: cuerpo,
        notificationDetails: notificationDetails,
      );
      return true;
    } catch (e) {
      debugPrint('Error al mostrar notificación: $e');
      return false;
    }
  }

  /// Registra una tarea en segundo plano con Workmanager condicionada a red
  /// (`NetworkType.connected`) cuando la plataforma es móvil nativa.
  /// Devuelve `true` si se programó en el sistema operativo o `false` si se
  /// debe depender del respaldo visual in-app.
  static Future<bool> programarSubidaEnSegundoPlano({
    required String albumTitle,
  }) async {
    await inicializar();

    if (soportaSegundoPlano) {
      try {
        await Workmanager().registerOneOffTask(
          'upload_${DateTime.now().millisecondsSinceEpoch}',
          backgroundUploadTaskKey,
          constraints: Constraints(networkType: NetworkType.connected),
          inputData: <String, dynamic>{'albumTitle': albumTitle},
        );
        return true;
      } catch (e) {
        debugPrint('Workmanager register falló: $e');
      }
    } else {
      debugPrint(
        'Workmanager no disponible en esta plataforma '
        '(web=$kIsWeb, platform=$defaultTargetPlatform); se usa respaldo in-app.',
      );
    }

    if (soportaNotificacionesNativas) {
      return mostrarNotificacion(
        titulo: '¡Álbum publicado con éxito!',
        cuerpo: 'Tu álbum "$albumTitle" ya está disponible en StreamTunes.',
      );
    }

    return false;
  }
}
