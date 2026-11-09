import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

const String backgroundUploadTaskKey = 'streamtunes_background_album_upload';

/// Función top-level requerida por Workmanager para el aislamiento del isolate en segundo plano.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == backgroundUploadTaskKey ||
        task == Workmanager.iOSBackgroundTask) {
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

  static Future<void> inicializar() async {
    if (_initialized) return;

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
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

    _initialized = true;
  }

  static Future<void> mostrarNotificacion({
    required String titulo,
    required String cuerpo,
  }) async {
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
    } catch (e) {
      debugPrint('Error al mostrar notificación: $e');
    }
  }

  /// Registra una tarea de subida pesada en segundo plano con Workmanager
  /// condicionada a tener conexión a internet (`NetworkType.connected`).
  static Future<void> programarSubidaEnSegundoPlano({
    required String albumTitle,
  }) async {
    await inicializar();

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        await Workmanager().registerOneOffTask(
          'upload_${DateTime.now().millisecondsSinceEpoch}',
          backgroundUploadTaskKey,
          constraints: Constraints(networkType: NetworkType.connected),
          inputData: <String, dynamic>{'albumTitle': albumTitle},
        );
        return;
      } catch (e) {
        debugPrint('Workmanager register fallback: $e');
      }
    }

    // Fallback simulado para entornos Web / Desktop donde Workmanager nativo no corre
    Future.delayed(const Duration(seconds: 5), () async {
      await mostrarNotificacion(
        titulo: '¡Álbum publicado con éxito!',
        cuerpo: 'Tu álbum "$albumTitle" ya está disponible en StreamTunes.',
      );
    });
  }
}
