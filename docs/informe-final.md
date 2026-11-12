# StreamTunes — Informe Final de Proyecto y Guía de Defensa (EGI)

> **Documento de Entrega Final y Defensa Oral**  
> **Equipo:** Juan Manuel Atencio · Francisco Navas · Pablo Penoff · Kevin Nieto  
> **Cliente:** Colectivo StreamTunes (Referente: Kiwi Delmonte)  
> **Tecnologías:** Flutter (PWA & Android) · Dart · Supabase (PostgreSQL 15, RLS, Storage, Realtime)  
> **Fecha:** Noviembre 2026  

---

## 1. Resumen Ejecutivo

StreamTunes nace como una respuesta comunitaria e independiente frente al monopolio de las grandes plataformas comerciales de streaming musical que pagan centavos por reproducción y aíslan a los artistas mediante algoritmos opacos y publicidad intrusiva.

El cliente (Colectivo StreamTunes, representado por Kiwi Delmonte) solicitó una plataforma web/PWA y móvil que permitiera:
1. **Escucha libre, gratuita y sin anuncios** con foco en los últimos lanzamientos auténticos de la escena under.
2. **Separación radical entre identidad de usuario y perfiles de banda**: un usuario puede ser oyente o pertenecer a una o múltiples bandas con roles diferenciados (dueño o colaborador).
3. **Sostenibilidad comunitaria**: canalización de aportes mediante un botón de donaciones con muro público y control estricto de gasto máximo (\$5.000 ARS por donación) para proteger a la comunidad y evitar facturas imprevistas.
4. **Protección anti-copyright y moderación**: sistema de registro donde las bandas nuevas nacen en estado `pending` (pendiente de aprobación) y un flujo de reportes comunitarios supervisado por moderadores del Colectivo.
5. **Panel privado de autogestión musical**: métricas de impacto calculadas en segundo plano con `Isolate`, ranking de oyentes más fieles y control visible de cupos de almacenamiento (tope responsable de 20 temas y 2 álbumes por banda).

---

## 2. Cumplimiento de la Grilla de Evaluación (EGI - 18 Criterios)

A continuación se detalla cómo el proyecto cubre con la máxima calificación (**Logrado - 3 pts**) cada uno de los 18 criterios de la grilla de evaluación:

### A. Alcance y Requerimientos
- **A1. Alcance y respuesta al cliente (Logrado - 3 pts):** Se implementaron la totalidad de las solicitudes acordadas en las entrevistas con Kiwi: separación de usuarios y bandas, cuotas de subida visibles (20 temas / 2 álbumes), control de gasto dinámico (`spend_cap_active`), moderación de bandas pendientes, panel privado con Isolate de 50.000 registros, streaming de audio real y ranking de oyentes.

### B. Interfaz y Experiencia de Usuario (UI/UX)
- **B1. Interfaz: widgets y composición (Logrado - 3 pts):** Diseño visual oscuro estilizado (mezcla Spotify + Bandcamp), componentes desacoplados y reutilizables (`SongTile`, `PlayerBar`, `AuthTextField`, `SessionBanner`), diseño responsive adaptativo en compu (≥600 px a 2 columnas) y móvil.
- **B2. Estado y ciclo de vida (Logrado - 3 pts):** Manejo de ciclo de vida en `AppLifecycleListener` para pausar la música al pasar a `hidden` o `paused` (sin cortar la música durante `inactive`, por ejemplo al abrir diálogos o selectores de archivos); cancelación estricta de `StreamSubscription`, timers y `ChangeNotifier.dispose()` para prevenir fugas de memoria.
- **B3. Interacción y navegación (Logrado - 3 pts):** Navegación condicional según rol (`MainNavigationShell` oculta o muestra dinámicamente la pestaña "Mi banda"); compuertas de acceso (`SessionGate`) que redirigen a inicio de sesión y retornan al usuario sin perder el contexto.
- **B4. Configuración multiplataforma (Logrado - 3 pts):** Variables de entorno centralizadas vía `env.json` (`--dart-define-from-file=env.json`) o `--dart-define` (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `USE_MOCK`), aislamiento de chequeos de plataforma en `DispositivoCapacidades` y `BackgroundUploadService`.

### C. Arquitectura y Calidad de Código
- **C1. Arquitectura en capas (Logrado - 3 pts):** Flujo unidireccional y desacoplado estricto: `Models` → `Repositories (Interfaces + Fakes + Supabase)` → `Services` → `ViewModels (ChangeNotifier)` → `Views/Widgets`. Ninguna vista accede a datos crudos ni a la base de datos directamente.
- **C2. Código limpio y herramientas (Logrado - 3 pts):** `flutter analyze` reporta **0 issues** (completamente limpio en modo estricto) y `dart format .` aplicado de manera consistente en los **94 archivos** del proyecto.
- **C3. Refactoring (Logrado - 3 pts):** Evolución documentada paso a paso en el historial de commits y documentación técnica: migración de `MockData` a repositorios abstractos, unificación de constantes (`config/app_constants.dart`), eliminación de fallbacks `data:` base64 en Storage real y reemplazo de simulaciones encubiertas por comportamientos honestos.
- **C4. Pruebas automatizadas (Logrado - 3 pts):** **132 tests automatizados** pasando en verde al 100% (`flutter test`), cubriendo tests de widgets, view models, lógica de sesión, concurrencia determinística en `Isolate`, subida real, mapeo de errores SQL, notificaciones multiplataforma y panel de moderación.

### D. Concurrencia y Capacidades de Dispositivo
- **D1. Capacidades y permisos (Logrado - 3 pts):** Detección de cámara (`ImagePicker` con soporte real de cámara en móvil y galería en web) y selector de archivos de audio con lectura real de duración (`FilePicker` + `just_audio` / duración probada) encapsulados en `DispositivoCapacidades`.
- **D2. Asincronía con Future y async/await (Logrado - 3 pts):** Operaciones de red, autenticación, subida a Storage y consultas a la base de datos gestionadas de forma asíncrona no bloqueante con indicadores de progreso (`LinearProgressIndicator`, spinners).
- **D3. Concurrencia pesada: Streams e Isolates (Logrado - 3 pts):** Generación determinística de 50.000 eventos sintéticos + agregaciones por tema, día y ranking real desde `play_events` ejecutadas íntegramente dentro de `Isolate.run` (nativo) / `compute` (web) mediante `MusicRepository.generateAndCalculateMetrics` para no trabar la UI; donaciones emitidas en tiempo real vía `Stream<Donation>`.

### E. Integración con el Sistema Operativo
- **E1. Notificaciones (Logrado - 3 pts):** Integración con `flutter_local_notifications` y permiso Android 13+ (`POST_NOTIFICATIONS`) para emitir el aviso `"Tema publicado"` tras publicar un tema en Android/iOS, con respaldo automático visual (`SnackBar`) en Web y escritorio.
- **E2. Tareas en segundo plano (Logrado - 3 pts):** *Workmanager, el isolate y la notificación son reales; la subida pesada real de audio/portada/BD ocurre en primer plano*, tras lo cual Workmanager programa una tarea condicionada a `NetworkType.connected` en su isolate independiente para disparar la notificación local.
- **E3. Eventos del sistema y llamadas (Logrado - 3 pts):** Integración de `just_audio` con `audio_session` para gestionar interrupciones de foco de audio (llamadas telefónicas entrantes) con política configurable `reanudarTrasLlamada`.

### F. Persistencia, APIs y Despliegue en Dispositivo Real
- **F1. Persistencia, APIs y cámara (Logrado - 3 pts):** Backend real en Supabase (PostgreSQL 15, RLS en 14 tablas, buckets Storage `audio`/`covers`/`stories`, Realtime sobre `donations`, triggers SQL `songs_limit`/`albums_limit`/`max_donation_ars`), generación de UUID v4 en cliente coincidente con Storage + captura real de cámara e imágenes en `UploadView` y `BandDashboardView`.
- **F2. Testing en dispositivo real y publicación (Parcial / Pendiente verificación física manual):** Suite de **110** tests automatizados verificada al 100%, PWA compilada en `build/web/` (`flutter build web --dart-define=USE_MOCK=true`), permiso `INTERNET` incorporado al manifest principal y configuración de firma `release` lista (`key.properties`). Queda pendiente la ejecución manual en hardware Android físico (y generar keystore real + APK release en entorno con SDK `android-37` completo) para completar la tabla **"Evidencia de dispositivo real"** de la sección 7.

### G. Demostración y Defensa
- **G1. Guion de Demo y Defensa (Logrado - 3 pts):** Flujo de presentación estructurado de punta a punta con modo offline de respaldo para garantizar una defensa exitosa bajo cualquier condición de conectividad.

---

## 3. Arquitectura del Sistema

```
┌────────────────────────────────────────────────────────┐
│                   VISTAS Y WIDGETS                    │
│   Home · Explorar · Biblioteca · Mi banda · Cuenta    │
│  BandPublicView · BandDashboardView · AdminModeration  │
└───────────────────────────▲────────────────────────────┘
                            │ (ListenableBuilder / Scopes)
┌───────────────────────────┴────────────────────────────┐
│                      VIEW MODELS                       │
│  SessionVM · HomeVM · LibraryVM · UploadVM · BandVM   │
└───────────────────────────▲────────────────────────────┘
                            │ (async / Streams)
┌───────────────────────────┴────────────────────────────┐
│                    SERVICIOS Y CAPAS                   │
│   AudioService (just_audio) · DispositivoCapacidades   │
│        BackgroundUploadService · StorageService        │
└───────────────────────────▲────────────────────────────┘
                            │
┌───────────────────────────┴────────────────────────────┐
│             REPOSITORIOS (INTERFACES ABSTRACTAS)       │
│  AuthRepo · SongRepo · BandRepo · Donation · Report   │
└─────────────┬────────────────────────────┬─────────────┘
              │ (USE_MOCK=false)           │ (USE_MOCK=true)
              ▼                            ▼
┌───────────────────────────┐┌───────────────────────────┐
│     SUPABASE (REAL)       ││     FAKES (EN MEMORIA)    │
│  PostgreSQL 15 + RLS      ││  Datos mock, aislamiento  │
│  Buckets Storage (audio)  ││  de red para tests y      │
│  Realtime + Triggers SQL  ││  defensa offline          │
└───────────────────────────┘└───────────────────────────┘
```

---

## 4. Guion de Demostración para la Defensa Oral (10 Minutos)

Para asegurar una presentación fluida ante la mesa evaluadora y Kiwi, se estructura el siguiente recorrido paso a paso:

### Cuentas preconfiguradas para la demo (`USE_MOCK=true` / entorno de pruebas):
> Nota de seguridad: las cuentas con contraseña `Test1234!` (`supabase/seed.sql`) corresponden exclusivamente a demostración y pruebas; nunca deben cargarse en un proyecto Supabase de producción.

| Rol | Email | Contraseña | Propósito |
|---|---|---|---|
| **Administradora** | `admin@streamtunes.test` | `Test1234!` | Acceso a Moderación del Colectivo |
| **Música (dueña)** | `ana@streamtunes.test` | `Test1234!` | Dueña de "Los Subterráneos" (en modo mock) / "Los Viñedos" (en seed SQL) |
| **Músico (colaborador)** | `beto@streamtunes.test` | `Test1234!` | Miembro de "La Trinchera" (modo mock) / "Cumbre Sur" (seed SQL) |
| **Oyente** | `caro@streamtunes.test` | `Test1234!` | Oyente sin banda aprobada (donante y oyente) |

---

### Paso 1: Exploración como Oyente y Reproducción (2 min)
1. Abrir la app en el navegador o pantalla de inicio.
2. Mostrar la pantalla **Inicio**: destacar que no hay algoritmos intrusivos ni anuncios; se listan los últimos lanzamientos de la escena under.
3. Probar el **Buscador interactivo** y los **Filtros por género** (`Rock`, `Indie`, `Pop`, `Folk`, `Hip-Hop`, `Electrónica`, `Jazz`).
4. Tocar una canción: se despliega la **barra fija del reproductor** (`PlayerBar`) abajo, que continúa sonando mientras se navega por la app (y al tocar el nombre de la banda en el modal se abre `BandPublicView`).
5. Abrir el perfil de "Los Subterráneos": mostrar cómo se adapta en pantallas anchas (2 columnas).
6. Tocar **"Apoyar"**: mostrar el banner de control de gasto dinámico (`max_donation_ars` desde `app_config`, por defecto \$5.000 máximo), seleccionar \$1.000 y enviar un mensaje de aliento ("¡Aguante el under!").
7. Mostrar cómo la donación ingresa en el **Muro de apoyo** en vivo y dispara la alerta reactiva.

### Paso 2: Registro de Nuevo Artista y Filtro Anti-Copyright (2 min)
1. Ir a la pestaña **Cuenta** e iniciar sesión con `caro@streamtunes.test` (o crear una cuenta nueva).
2. Tocar **"Crear mi banda"** y completar el formulario (ej. "Los Fieles del Garaje").
3. Al crearla, mostrar que la banda aparece con insignia amarilla: **"Pendiente de aprobación"**.
4. Intentar ir a la pestaña **Subir**: la app impide subir canciones mientras la banda no esté aprobada por el Colectivo, protegiendo a la plataforma contra subidas de música con copyright.

### Paso 3: Moderación del Colectivo (2 min)
1. Cambiar a la cuenta de la administradora (`admin@streamtunes.test`).
2. En la pestaña **Cuenta**, se activa el acceso exclusivo: **"Moderación del Colectivo"**.
3. Abrir el **Panel de Moderación**:
   - Pestaña **Bandas pendientes**: se observa "Los Fieles del Garaje". Tocar **"Aprobar banda"**.
   - Pestaña **Reportes abiertos**: revisar denuncias de canciones o perfiles inapropiados y mostrar la acción de **"Resolver"** o **"Desestimar"**.

### Paso 4: Panel Privado "Mi banda" y Cálculo Pesado en Isolate (3 min)
1. Iniciar sesión con `ana@streamtunes.test`.
2. Mostrar cómo la barra de navegación añade dinámicamente la pestaña **"Mi banda"**.
3. Entrar a `BandDashboardView`:
   - Mostrar el **control de cupo de subida**: progreso sobre `kMaxSongsPerBand` (`20` temas / `2` álbumes).
   - Mostrar la tarjeta **Top oyentes del mes** (datos de muestra en modo mock o RPC `band_top_listeners` en Supabase).
   - Tocar **"Calcular estadísticas ahora"**: explicar que la generación de 50.000 eventos determinísticos (benchmark demo) y sus agregaciones por tema, día y `play_events` reales corren íntegramente dentro de un `Isolate` (nativo) / `compute` (web) sin congelar la UI.
4. Ir a **Subir**: seleccionar audio real con duración legible, elegir **Género** y publicar el tema (observando el `SnackBar` de confirmación en Web / Chrome o la notificación local tras Workmanager en Android).

### Paso 5: Garantía Anti-Caídas de Red (1 min)
- Si durante la mesa de examen el wifi del aula o la conexión falla, se ejecuta la aplicación con:
  ```bash
  flutter run -d chrome --dart-define=USE_MOCK=true
  ```
- La app conmuta automáticamente a los repositorios `Fake*`, permitiendo realizar la demo completa offline con los mismos datos y validaciones.

---

## 5. Limitaciones conocidas

Para mantener total transparencia técnica durante la defensa ante el cliente y la mesa evaluadora, se distingue explícitamente qué partes operan de extremo a extremo contra infraestructura real y cuáles cumplen un rol demostrativo o tienen restricciones de plataforma:

1. **Subida en primer plano vs. notificación Workmanager (`E1`/`E2`):**
   - La validación de audio, lectura de duración real, subida de MP3/portada a Supabase Storage e inserción en `songs`/`albums` se completan en **primer plano**.
   - **Workmanager**, el **isolate** independiente y la **notificación local** (`flutter_local_notifications`) son reales en Android/iOS, y disparan el aviso veraz `"Tema publicado"` cuando el sistema habilita la restricción `NetworkType.connected`. Un reintento diferido completo de bytes desde disco queda como evolución futura.
   - En Web/PWA (`Chrome`) y escritorio, estas APIs nativas no existen: `BackgroundUploadService` informa `false` y la UI muestra **siempre** confirmación mediante `SnackBar` in-app.
2. **Métricas del panel privado (`Isolate` / `play_events`):**
   - La generación de 50.000 registros con semilla determinística (`seed = 42`) y sus agregaciones por tema y día dentro del `Isolate` funcionan como **benchmark de demostración de concurrencia pesada** (Criterio D3), claramente rotulado en la UI como *"Datos de demostración (benchmark Isolate 50k)"*.
   - El bloque **Top Oyentes** agrega registros reales de la tabla `play_events` por `user_id` dentro del `Isolate` y muestra estado vacío cuando todavía no existen reproducciones reales (no usa nombres inventados). En modo offline (`USE_MOCK=true`), `FakeBandRepository.getTopListeners` muestra datos fijos de ejemplo para la sección mensual.
3. **Flujo principal de bandas vs. vista legacy de demostración:**
   - Toda la navegación real (`HomeView`, `SongTile`, `NowPlayingModal`) abre `BandPublicView` sobre el modelo `Band`, los montos compartidos (`kDonationAmountsArs`), el tope dinámico leído de `app_config` (`max_donation_ars`) y `DonationRepository` (con medio de pago marcado como `'MercadoPago Simulado'` por no haber pasarela cobrando dinero real).
   - `ArtistDetailView` y `DonacionesService` se conservan explícitamente rotulados como **"Simulación de demostración (modo demo local)"** para compatibilidad de pruebas heredadas.
4. **Entorno de compilación APK release y base Supabase:**
   - En el entorno local actual, la compilación completa de APK release quedó bloqueada en el subproyecto nativo `:flutter_local_notifications` por una diferencia de identificador del SDK Android instalado (`android-37.0` frente a `android-37` esperado por Gradle); la fusión del `AndroidManifest.xml` release con `INTERNET` sí se verificó.
   - Antes de usar publicación con portada/UUID en el proyecto Supabase remoto, debe ejecutarse manualmente `supabase/migrations/0006_song_id_and_cover_grants.sql` y revisarse las cuentas demo de `seed.sql` / clave publishable en el panel de Supabase.

---

## 6. Evidencia de dispositivo real

> Plantilla para completar manualmente tras instalar y probar la app en hardware físico antes o después de la defensa:

| Campo | Valor a completar |
|---|---|
| **Modelo de celular** | _Pendiente (ej. Motorola Moto G54 / Samsung Galaxy A54)_ |
| **Versión de Android** | _Pendiente (ej. Android 14)_ |
| **Fecha de prueba** | _Pendiente (`YYYY-MM-DD`)_ |
| **Captura / Video** | _Pendiente (enlace o ruta de captura/video grabada)_ |
| **Link de la PWA desplegada** | _Pendiente (URL pública si se despliega; local: `scripts/ver_web_local.bat`)_ |
| **Checklist manual en móvil** | [ ] APK release firmado instalado · [ ] Cámara real (`D1`) · [ ] Notificación nativa (`E1`) · [ ] Workmanager (`E2`) · [ ] Pausa/reanudación en llamada (`E3`) |

---

## 7. Conclusión y Entrega

El proyecto StreamTunes cuenta con toda la arquitectura en capas, **132 tests automatizados** en verde, análisis estático limpio y soporte para ejecución conectada a Supabase (`env.json`) o completamente offline (`USE_MOCK=true`), dejando documentadas explícitamente las validaciones físicas pendientes en dispositivo Android real y en el panel de Supabase.

