# Plan de Acción Integral - StreamTunes MVP (Fase 2)

## 📌 Contexto del Proyecto para el Asistente de IA (Antigravity/Cursor)

**StreamTunes** es una aplicación multiplataforma (PWA para Web y Móvil) orientada a la difusión y monetización de bandas independientes (under). Incluye un reproductor global continuo, interfaz oscura, subida de temas/álbumes en segundo plano con notificaciones locales, donaciones en vivo en tiempo real y estadísticas pesadas procesadas en paralelo.

### ⚠️ Reglas Arquitectónicas y de Código (Obligatorias)
1. **Arquitectura en Capas:** Separación estricta y unidireccional: `models`, `repositories`, `services`, `view_models`, `views` y `widgets`.
2. **Gestión de Estado Sin Prop-Drilling:** Uso exclusivo de `ChangeNotifier`, `ListenableBuilder` y los `InheritedNotifier` globales existentes (`ReproductorScope` y `LibraryScope`). **PROHIBIDO el prop-drilling** (pasar view models o controladores a través de constructores en widgets anidados). Prohibido introducir paquetes externos de estado como `provider` o `riverpod`.
3. **Desacoplamiento Multiplataforma:** Prohibido invocar `kIsWeb`, `Platform.isIOS`, `defaultTargetPlatform`, etc., dentro de Vistas o ViewModels. Toda lógica dependiente del entorno debe residir en `DispositivoCapacidades` u otros servicios de infraestructura.
4. **Asincronía y Concurrencia:** Uso adecuado de `Future` / `async-await`, aislamiento de cómputos pesados (`Isolate.run` en nativo / `compute` en web encapsulado) y gestión segura de `Streams` (suscripción activa y cancelación obligatoria en `dispose()`).
5. **Calidad y No Regresión:** El código debe superar `dart format .`, `flutter analyze` (sin advertencias ni errores) y los 8 tests existentes en `test/widget_test.dart` con `flutter test`.

---

## 🚀 Fase 1: Asincronía, Segundo Plano y Streams en Vivo (Criterios E2, D3)

**Contexto:** Se detectaron fallas críticas en la ejecución de la tarea de segundo plano de Workmanager (el isolate no inicializa el motor de notificaciones locales) y el servicio de donaciones en vivo no inicia su ciclo de emisión periódica en el perfil.

### Prompt 1.1: Inicialización de Notificaciones en Isolate de Workmanager (Criterio E2)
> "Actúa como un experto en Flutter y arquitectura en segundo plano. Revisa el archivo `lib/services/background_upload_service.dart`.
> 
> **Problema:** En la función top-level `@pragma('vm:entry-point') void callbackDispatcher()`, la tarea de Workmanager falla al mostrar la notificación local porque se ejecuta en un isolate de Dart independiente sin los bindings ni los plugins registrados, y la instancia estática de `_notificationsPlugin` no está inicializada en ese espacio de memoria.
> 
> **Requerimientos de corrección:**
> 1. En `callbackDispatcher()`, importa `dart:ui` y asegura los bindings con `WidgetsFlutterBinding.ensureInitialized()` y `DartPluginRegistrant.ensureInitialized()`.
> 2. Inicializa correctamente `FlutterLocalNotificationsPlugin` con sus ajustes de plataforma (`AndroidInitializationSettings`, `DarwinInitializationSettings`) dentro del isolate antes de disparar la notificación de '¡Álbum publicado con éxito!'.
> 3. Asegura que el canal de notificación Android cuente con importancia alta (`Importance.max`) y prioridad alta para garantizar su visibilidad en segundo plano."

### Prompt 1.2: Activación y Ciclo de Vida del Stream de Donaciones (Criterio D3)
> "Actúa como un desarrollador senior en Flutter. Revisa `lib/view_models/artist_detail_view_model.dart` y `lib/services/donaciones_service.dart`.
> 
> **Problema:** El método `iniciarSimulacion()` de `DonacionesService` nunca es invocado, por lo que el stream no emite eventos automáticos en runtime. Además, si se inicia la simulación, debe detenerse limpiamente al salir de la pantalla para evitar fugas de memoria y timers zombis.
> 
> **Requerimientos de corrección:**
> 1. En `ArtistDetailViewModel`, agrega un parámetro configurable en el constructor `autoIniciarSimulacion = true` (para permitir que los tests unitarios lo desactiven si lo desean, preservando compatibilidad con `widget_test.dart`).
> 2. Si `autoIniciarSimulacion` es verdadero, inicia la simulación invocando `_donacionesService.iniciarSimulacion(targetArtistId: artist.id)`.
> 3. En el método `dispose()` de `ArtistDetailViewModel`, además de cancelar `_donacionesSubscription?.cancel()`, detén la simulación llamando a `_donacionesService.detenerSimulacion()`.
> 4. Verifica que el test `Bloque 5: DonacionesService emite vía stream...` en `widget_test.dart` siga pasando exitosamente."

---

## 🎨 Fase 2: Lógica de Negocio, UX y Restricciones del Cliente (Criterio A1)

**Contexto:** Ajustar la experiencia de usuario (UX) en el detalle del artista priorizando el contenido musical, restringiendo la visibilidad de analíticas sensibles al dueño del perfil, y reflejando moderación y topes de gasto solicitados por el cliente (Kiwi).

### Prompt 2.1: Priorización de Canciones y Privacidad de Métricas
> "Revisa la vista de detalle del artista en `lib/views/artist_detail_view.dart`.
> 
> **Problema:** Actualmente la sección 'Canciones más escuchadas' está ubicada al final de la pantalla, obligando al usuario a hacer scroll por debajo de las historias, biografía y panel de estadísticas. Asimismo, las métricas pesadas procesadas por el isolate (reproducciones y oyentes) están visibles para cualquier oyente.
> 
> **Requerimientos de corrección:**
> 1. Mueve el bloque 'Canciones más escuchadas' a la parte superior del cuerpo de la vista, inmediatamente debajo de la información principal del artista (avatar, nombre, género y enlaces/historias).
> 2. Añade un flag booleano `esDuenoDelPerfil` en `ArtistDetailView` (por defecto `true` para asegurar retrocompatibilidad con los tests y previsualización).
> 3. Si `esDuenoDelPerfil` es `true`, muestra el panel 'Métricas en Segundo Plano (Isolate)'. Si es `false`, oculta el panel de estadísticas privadas a visitantes casuales."

### Prompt 2.2: Moderación de Perfil y Topes de Gasto Activos (Feedback Kiwi)
> "En `lib/views/artist_detail_view.dart`, implementa los requisitos de moderación y control presupuestario solicitados por Kiwi.
> 
> **Requerimientos de corrección:**
> 1. Agrega en el `AppBar` un botón de acción con ícono de bandera (`Icons.flag_outlined`) con tooltip 'Reportar perfil'. Al pulsarlo, muestra un `SnackBar` confirmando: 'Perfil reportado para moderación de contenido.'
> 2. En la sección de donaciones y dentro del diálogo `_mostrarDialogoDonar`, agrega un banner informativo o aviso visual con estilo de advertencia/información que indique: '⚠️ Estamos con alta demanda - Topes de gasto activos (máx. \$5.000 ARS por donación)' para reflejar de forma explícita la restricción presupuestaria."

### Prompt 2.3: Validación Estricta de Límites de Subida en el ViewModel
> "Revisa `lib/view_models/upload_view_model.dart` y `lib/views/upload_view.dart`.
> 
> **Problema:** El aviso 'Límite inicial: máximo 2 álbumes o 20 temas por banda' en `UploadView` es solo una etiqueta visual; el `UploadViewModel` no valida estos límites y permite publicar de forma ilimitada.
> 
> **Requerimientos de corrección:**
> 1. En `UploadViewModel.publicarTema()`, consulta las canciones actuales de la banda mediante `_musicRepository.getSongsByArtist(artistId)`.
> 2. Valida que la banda no supere los 20 temas en total.
> 3. Obtén la lista de álbumes ya registrados de esa banda. Si ya cuenta con 2 álbumes distintos y el nuevo tema pertenece a un tercer álbum diferente, rechaza la subida.
> 4. Ante una infracción de límite, asigna el mensaje correspondiente a `_error` (ej. 'Límite de subida alcanzado: máximo 2 álbumes o 20 temas por banda'), notifica a los listeners y retorna `false`.
> 5. Asegúrate de que `test/widget_test.dart` (Bloque 6) continúe pasando, dado que la prueba publica un tema dentro del umbral permitido."

---

## 🧹 Fase 3: Refactorización Arquitectónica y Desacoplamiento (Criterios C2, C3)

**Contexto:** Erradicar deudas técnicas de la arquitectura: suprimir el paso manual de modelos por constructores (prop-drilling), sanear getters duplicados, remover la carpeta redundante `state/` y desacoplar chequeos de plataforma en ViewModels.

### Prompt 3.1: Supresión de Prop-Drilling y Limpieza de Modelos Duplicados
> "Vamos a sanear la arquitectura de estado de la aplicación.
> 
> **Archivos a intervenir:** `lib/main.dart`, `lib/views/main_navigation_shell.dart`, `lib/views/home_view.dart`, `lib/views/library_view.dart`, `lib/views/artist_detail_view.dart`, `lib/widgets/song_tile.dart`, `lib/widgets/player_bar.dart` y `lib/view_models/reproductor_view_model.dart`.
> 
> **Requerimientos de corrección:**
> 1. **Eliminar Prop-Drilling:** `main.dart` ya inyecta en la raíz `ReproductorScope` y `LibraryScope` (que extienden de `InheritedNotifier`). Elimina los parámetros por constructor `playerModel` y `libraryModel` en `MainNavigationShell`, `HomeView`, `LibraryView`, `ArtistDetailView`, `SongTile` y `PlayerBar`.
> 2. Haz que cada widget obtenga su modelo directamente desde el árbol usando `ReproductorScope.of(context)` o `LibraryScope.of(context)` y reconstruya su UI con `ListenableBuilder`.
> 3. **Consolidar `reproductor_view_model.dart`:** Elimina los getters duplicados o métodos redundantes en español/inglés, conservando obligatoriamente los nombres requeridos por `test/widget_test.dart` (`currentSong`, `isPlaying`, `hasSong`, `play`, `pause`, `togglePlay`, `cambiarTema`).
> 4. **Eliminar carpeta `lib/state/`:** Reemplaza cualquier import residual proveniente de `lib/state/` por su respectivo archivo en `lib/view_models/` y elimina de forma definitiva los archivos puente en `lib/state/` (`player_model.dart` y `library_model.dart`)."

### Prompt 3.2: Desacoplamiento de Plataforma y Aislamiento de `kIsWeb`
> "Revisa `lib/view_models/artist_detail_view_model.dart` y `lib/services/dispositivo_capacidades.dart`.
> 
> **Problema:** En `ArtistDetailViewModel.calcularEstadisticasIsolate()`, existe una llamada directa a `kIsWeb ? compute(...) : Isolate.run(...)`, lo que viola la Regla 3 de no usar condicionales de plataforma en ViewModels.
> 
> **Requerimientos de corrección:**
> 1. En `DispositivoCapacidades` (o en un servicio específico de cómputo en segundo plano), crea un método genérico como `Future<R> ejecutarComputoPesado<T, R>(ComputeCallback<T, R> callback, T message)` que encapsule la decisión de usar `compute` en Web o `Isolate.run` en plataformas nativas.
> 2. En `ArtistDetailViewModel`, reemplaza el ternario directo con la llamada al método de capacidades/servicio, removiendo cualquier import de `kIsWeb` del ViewModel.
> 3. Mantén intacto el getter `Future<bool> get tieneCamara` en `DispositivoCapacidades` y su uso en `UploadViewModel` para preservar el paso del test `Bloque 3` en `widget_test.dart`."

---

## 📦 Fase 4: Sincronización de Identidad, Configuración y QA Final

**Contexto:** Unificar el nombre del proyecto en todas las capas del sistema (Dart, Android y dependencias), asegurar el aislamiento en el control de versiones y validar la suite de pruebas.

### Prompt 4.1: Renombrado Integral del Paquete y Sincronización de Imports
> "Vamos a renombrar formalmente el proyecto de `changenotifier_ejercicio` a `streamtunes`.
> 
> **Requerimientos de corrección:**
> 1. En `pubspec.yaml`, actualiza `name: streamtunes` y ajusta su descripción.
> 2. Actualiza **todos** los imports absolutos en `lib/` y `test/` (por ejemplo en `main.dart`, `widget_test.dart`, etc.) cambiando `import 'package:changenotifier_ejercicio/...'` por `import 'package:streamtunes/...'` (o usando imports relativos donde corresponda).
> 3. En `android/app/src/main/AndroidManifest.xml`, actualiza la etiqueta `android:label="StreamTunes"`.
> 4. En `android/app/build.gradle.kts`, actualiza el `namespace = "com.streamtunes.app"` y `applicationId = "com.streamtunes.app"`.
> 5. Asegúrate de que la carpeta `.idea/` esté excluida en el archivo `.gitignore` raíz del repositorio.
> 6. Ejecuta `dart format .`, `flutter analyze` y confirma que los 8 tests unitarios y de widgets pasen con éxito ejecutando `flutter test`."
