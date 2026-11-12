# StreamTunes 🎵

Plataforma de streaming de música y financiamiento directo para bandas independientes y música under. Desarrollada con **Flutter (PWA Web, Android, iOS y Windows)** y backend en la nube con **Supabase (PostgreSQL 15, RLS, Storage, Auth y Realtime)**.

El proyecto cuenta con un doble backend desacoplado que permite operarlo tanto en producción conectado a Supabase como en **Modo Demo Offline** totalmente en memoria para contingencias o defensas sin conexión a internet.

---

## 📌 Documentación Técnica

- 📘 [**Arquitectura y Modelo de Datos (`docs/arquitectura.md`)**](docs/arquitectura.md): Arquitectura en capas, diseño relacional en PostgreSQL, matriz de seguridad RLS y Storage.
- 📋 [**Requerimientos y Análisis de Alcance (`docs/requerimientos.md`)**](docs/requerimientos.md): Análisis de viabilidad técnica, mitigación de riesgos de hosting y puntos de validación con el cliente.
- 🎓 [**Informe Final y Guía de Defensa (`docs/informe-final.md`)**](docs/informe-final.md): Mapeo exhaustivo de los 18 criterios de evaluación EGI, guion de demostración paso a paso y limitaciones conocidas.

---

## ✨ Funcionalidades Principales

1. **Identidad y Cuentas:** Registro y autenticación con separación estricta entre la persona (`profiles`) y la entidad artística (`bands`). Soporte de visitantes anónimos.
2. **Perfil Público y Panel de Banda ("Mi banda"):**
   - Perfil público adaptativo (móvil y dos columnas en desktop/web): biografía, redes sociales, agenda de fechas (`band_events`), galería de fotos (`band_photos`), botón de seguir y tienda oficial de merch.
   - Panel privado de autogestión para miembros con tarjetas de resumen, donaciones recientes y accesos rápidos.
3. **Subida de Música y Almacenamiento:**
   - Carga de audio en formatos MP3, M4A o WAV hasta 50 MB con lectura real de duración (`DispositivoCapacidades`).
   - Control visual y en base de datos de cupos máximos iniciales por banda: **20 temas y 2 álbumes**.
   - Carga de portadas y soporte de letras sincronizadas en formato LRC.
4. **Reproductor Global Continuo:**
   - Reproducción sin interrupciones mediante `just_audio`.
   - Visualización y scroll automático de letras sincronizadas (Karaoke LRC).
   - Manejo de interrupciones de audio del sistema operativo (pausa y reanudación automática ante llamadas entrantes con `audio_session`).
5. **Biblioteca y Playlists:** Creación, edición y administración de listas de reproducción personales, con favoritos locales inmediatos.
6. **Módulo Comunitario de Donaciones:**
   - Aportes voluntarios con montos sugeridos y monto libre.
   - Control de gasto dinámico (`spend_cap_active` y tope máximo en `app_config`).
   - Muro público en tiempo real mediante Supabase Realtime (WebSockets sobre Postgres CDC).
7. **Fidelización por Código QR y Cola Offline:**
   - Generación de QR en cliente para acceso directo al perfil de la banda (`?band=<slug>`).
   - Respaldo offline con `PendingFollowService`: si el fan escanea en un sótano sin señal, la acción se guarda localmente en `SharedPreferences` y se sincroniza automáticamente al recuperar conexión.
8. **Métricas y Estadísticas:**
   - Agregaciones seguras en servidor mediante funciones RPC (`band_aggregated_stats`).
   - Ranking de **Top 10 Fans** (`band_top_fans`) con consentimiento de privacidad opt-in (`is_public_profile`).
   - Benchmark de concurrencia pesada sobre 50.000 registros procesados en segundo plano con `Isolate.run` (móvil) / `compute` (web).
9. **Moderación y Anti-Copyright:**
   - Las bandas nuevas nacen en estado `pending` (requieren aprobación humana antes de publicar).
   - Panel de moderación del colectivo (`AdminModerationView`) para aprobar/suspender bandas y gestionar reportes de contenido con regla de auto-ocultación tras denuncias reiteradas.
10. **Modo Demo Offline:** Respaldo completo en memoria (`USE_MOCK=true`) con datos semilla para operar el 100% de la UI sin depender de servidores externos.

---

## 🛠️ Stack Tecnológico

- **Frontend:** [Flutter](https://flutter.dev/) (SDK `>=3.13.1 <4.0.0`) · Dart 3
- **Gestión de Estado:** `ChangeNotifier`, `ListenableBuilder`, `InheritedNotifier` (`SessionScope`, `ReproductorScope`, `LibraryScope`, `RepositoriesScope`).
- **Backend & Nube:** [Supabase](https://supabase.com/):
  - **Auth:** Autenticación por email/contraseña y sesiones anónimas.
  - **Database:** PostgreSQL 15 con Row Level Security (RLS), triggers PL/pgSQL y funciones RPC `security definer`.
  - **Storage:** Buckets públicos `audio` y `covers` con políticas de subida por membresía y límites de tamaño.
  - **Realtime:** Suscripciones a cambios de base de datos para eventos de donaciones.
- **Plataformas Soportadas:** Web (PWA), Android (API 21+), iOS, Windows desktop.

---

## 📂 Arquitectura del Proyecto (`lib/`)

```
lib/
├── config/                  # Configuración de entorno y constantes de negocio
│   ├── app_config.dart      # Lectura de variables inyectadas por --dart-define
│   └── app_constants.dart   # Cupos (20 temas / 2 álbumes), topes de donación y timeouts
├── models/                  # Modelos de datos inmutables y serialización JSON
│   ├── album.dart           # Entidad de álbum
│   ├── band.dart            # Entidad de banda y enum BandStatus (pending/approved/suspended)
│   ├── band_event.dart      # Fechas de recitales y eventos
│   ├── band_membership.dart # Membresías de usuario y roles (owner/member)
│   ├── band_photo.dart      # Galería fotográfica oficial
│   ├── donation.dart        # Donaciones y enum DonationStatus
│   ├── metricas_artista.dart# Agregaciones de reproducciones y oyentes
│   ├── playlist.dart        # Listas de reproducción y temas asociados
│   ├── profile.dart         # Perfil personal y flag is_public_profile
│   ├── report.dart          # Denuncias comunitarias de contenido
│   └── song.dart            # Canciones, metadatos y letras LRC
├── repositories/            # Capa de acceso a datos desacoplada
│   ├── interfaces/          # Contratos abstractos (Auth, Band, Song, Storage, etc.)
│   ├── fake/                # Implementaciones en memoria sobre MockData (modo demo y tests)
│   ├── supabase/            # Implementaciones reales sobre Supabase SDK y PostgREST
│   └── app_repositories.dart# Factoría abstracta según flag USE_MOCK
├── services/                # Servicios de infraestructura y hardware
│   ├── audio_service.dart   # Reproducción y gestión de foco con audio_session
│   ├── background_upload_service.dart # Notificaciones locales y Workmanager nativo
│   ├── dispositivo_capacidades.dart   # Abstracción multiplataforma de cámara y archivos
│   ├── donaciones_service.dart        # Streams de eventos de donación
│   ├── lrc_parser.dart                # Parseo y sincronización temporal de letras LRC
│   ├── music_repository.dart          # Benchmark de 50k registros en Isolate
│   ├── pending_follow_service.dart    # Cola offline en SharedPreferences para QR
│   ├── qr_resolution_service.dart     # Resolución de enlaces y parámetros QR
│   └── supabase_service.dart          # Inicialización del cliente Supabase
├── theme/                   # Paleta visual oscura y tipografías (AppTheme)
├── view_models/             # Estado de presentación basado en ChangeNotifier
│   ├── band_dashboard_view_model.dart # Métricas y gestión de la banda activa
│   ├── band_public_view_model.dart    # Perfil público, donaciones y seguimiento
│   ├── home_view_model.dart           # Búsqueda, filtrado por género y catálogo
│   ├── library_view_model.dart        # Playlists y favoritos
│   ├── reproductor_view_model.dart    # Control de reproducción y letra activa
│   ├── session_view_model.dart        # Sesión, bandas activas y moderación
│   └── upload_view_model.dart         # Subida, validación de audio y cupos
├── views/                   # Vistas adaptativas de la aplicación
│   ├── account_view.dart              # Gestión de perfil y selector de banda
│   ├── admin_moderation_view.dart     # Panel de aprobación del Colectivo
│   ├── band_dashboard_view.dart       # Panel privado de la banda
│   ├── band_public_view.dart          # Perfil público de la banda
│   ├── create_band_view.dart          # Formulario para fundar una banda
│   ├── empty_state_view.dart          # Pantallas de estado vacío
│   ├── home_view.dart                 # Exploración principal de temas
│   ├── library_view.dart              # Pestaña de biblioteca y playlists
│   ├── login_view.dart / register_view.dart # Ingreso y registro
│   ├── main_navigation_shell.dart     # Shell con NavigationBar / NavigationRail
│   ├── session_gate.dart              # Compuerta de autenticación contextual
│   └── upload_view.dart               # Formulario de publicación musical
└── widgets/                 # Componentes reutilizables y Scopes de estado
    ├── auth_widgets.dart    # Campos de texto y banners de sesión
    ├── now_playing_modal.dart # Reproductor en modal completo con letras
    ├── player_bar.dart      # Barra inferior persistente de audio
    ├── session_scope.dart   # InheritedNotifier para SessionViewModel
    ├── reproductor_scope.dart # InheritedNotifier para ReproductorViewModel
    └── song_tile.dart       # Item de tema con menú de playlist
```

---

## ⚙️ Configuración del Entorno

### 1. Variables de Entorno (`env.json`)
Copiá la plantilla de variables en la raíz del proyecto:
```bash
copy env.example.json env.json
```
Completá tus credenciales de Supabase en `env.json` (archivo ignorado por Git):
```json
{
  "SUPABASE_URL": "https://TU-PROYECTO.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "TU_CLAVE_PUBLISHABLE_ANON"
}
```

### 2. Base de Datos en Supabase
En el panel de tu proyecto en Supabase (**SQL Editor**), ejecutá las migraciones en orden correlativo:
1. `supabase/migrations/0001_schema.sql`: Tipos enum, tablas principales, triggers de cupo y funciones de RLS.
2. `supabase/migrations/0002_rls.sql`: Habilitación de Row Level Security y políticas base en todas las tablas.
3. `supabase/migrations/0003_hardening.sql`: Privilegios por columna y RPCs de moderación (`set_band_status`, `set_song_hidden`).
4. `supabase/migrations/0004_storage_realtime.sql`: Configuración de buckets y publicación Realtime.
5. `supabase/migrations/0005_song_covers_and_band_edits.sql`: Portadas individuales por tema y edición por dueños.
6. `supabase/migrations/0006_song_id_and_cover_grants.sql`: Grants de cliente para UUIDs v4 y portadas.
7. `supabase/migrations/0007_public_ranking_events_and_stats.sql`: Eventos, fotos, follows, ranking opt-in y RPC de métricas.
8. `supabase/migrations/0008_storage_audio_limits_and_stats_security.sql`: Límite de 50 MB en audio y seguridad en RPC.
9. `supabase/migrations/0009_consolidated_grants_and_policy_fixes.sql`: Consolidación final de privilegios de menor acceso y RPC `band_follower_count`.

> 💡 **Datos de prueba para desarrollo local:** Para cargar bandas, canciones y usuarios demo en un entorno de pruebas, ejecutá `supabase/seed.sql` (ver usuarios y contraseñas documentados dentro de ese mismo archivo). **No ejecutar en entornos productivos.**

---

## 🚀 Ejecución y Compilación

### Scripts de Acceso Rápido (`scripts/`)
Para mayor comodidad en Windows, la carpeta `scripts/` incluye ejecutables directos:
- `scripts/iniciar.bat`: Inicia la app conectada a Supabase leyendo `env.json`.
- `scripts/iniciar_demo_offline.bat`: Inicia la app inmediatamente en modo demo en memoria (`USE_MOCK=true`).
- `scripts/ver_web_local.bat`: Abre un servidor HTTP local en el puerto 8080 (compila la PWA automáticamente si no existiera).

### Comandos CLI de Flutter

**1. Modo Conectado a Supabase:**
```bash
flutter run -d chrome --dart-define-from-file=env.json
```

**2. Modo Demo Offline (Respaldo sin Internet):**
```bash
flutter run -d chrome --dart-define=USE_MOCK=true
```

**3. Compilación PWA Web:**
```bash
flutter build web --dart-define=USE_MOCK=true
```

**4. Compilación Android Release Firmada (`apk`):**
1. Generar la keystore de subida (ej. `android/app/upload-keystore.jks`).
2. Copiar `android/key.properties.example` como `android/key.properties` y completar las contraseñas y alias.
3. Compilar el APK release:
```bash
flutter build apk --release --dart-define-from-file=env.json
```

---

## 🧪 Pruebas Automatizadas

La suite del proyecto incluye **132 tests automatizados** sin dependencias externas (corren 100% offline).

Para ejecutar todos los tests:
```bash
flutter test
```

### Cobertura de la Suite (`test/`)
- `account_view_enhancements_test.dart`: Perfil de usuario, historial de donaciones y cambio de banda activa.
- `auth_views_test.dart`: Flujo de inicio de sesión, registro, validación de contraseñas y cierre de sesión.
- `background_upload_service_test.dart`: Notificaciones locales de publicación y fallback a SnackBar in-app.
- `band_dashboard_view_test.dart`: Métricas del panel privado ("Mi banda"), cupos y donaciones recibidas.
- `band_public_view_test.dart`: Perfil público adaptativo de bandas, agenda de shows y botón de apoyo.
- `band_view_models_and_scopes_test.dart`: ViewModels de artistas, scopes de dependencias y donaciones en tiempo real.
- `core_app_flows_test.dart`: Flujos nucleares del MVP: ciclo de vida (`AppLifecycleListener`), responsividad, isolate de 50k y límites de subida.
- `donations_stats_moderation_test.dart`: Validación de topes de gasto, ranking top fans opt-in y flujo de reportes/moderación.
- `empty_state_view_test.dart`: Renderizado adaptativo de componentes `EmptyStateView`.
- `home_view_model_test.dart`: Catálogo principal, pull-to-refresh y filtros por género musical.
- `library_view_model_test.dart`: Creación, actualización y eliminación de playlists, y persistencia de favoritos.
- `lrc_and_client_features_test.dart`: Parseo de marcas de tiempo LRC y sincronización en cola offline de `PendingFollowService`.
- `playback_and_home_search_test.dart`: Búsqueda en tiempo real por título o banda y filtrado interactivo.
- `qr_resolution_test.dart`: Entrada por código QR, creación de sesión anónima y acción de seguimiento.
- `role_navigation_test.dart`: Adaptación dinámica de pestañas de navegación según rol del usuario.
- `session_gates_test.dart`: Bloqueo y redirección contextual en vistas protegidas (`SessionGate`).
- `session_view_model_test.dart`: Lógica de sesión, permisos administrativos y membresías.
- `supabase_donation_repository_test.dart`: Verificación de consultas e inserciones del repositorio de donaciones.
- `supabase_song_repository_test.dart`: Registro de eventos de reproducción y resolución de álbumes.
- `upload_flow_test.dart`: Subida guiada de música, selección de archivos de audio e inspección de duración.
- `upload_view_model_test.dart`: Validación de límites de tamaño, subida a Storage y manejo de errores de cuota.

---

## 🗄️ Esquema de Base de Datos y Seguridad (RLS)

Todas las tablas operan bajo `row level security` estricto en PostgreSQL:

| Tabla | Acceso Público (`anon`) | Acceso Autenticado (`authenticated`) | Reglas Clave de Seguridad |
|---|---|---|---|
| `bands` | `SELECT` | `SELECT`, `INSERT` y `UPDATE` (por columna) | Solo se listan bandas `approved` al público. Modificación restringida al `owner`. |
| `songs` | `SELECT` | `SELECT`, `INSERT` (por columna), `DELETE` | Canciones ocultas (`hidden = true`) no se muestran. Inserción restringida a miembros de la banda. |
| `albums` | `SELECT` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | Creación y edición limitada a miembros de la banda titular. |
| `profiles` | `SELECT (id, display_name)` | `SELECT` completo, `UPDATE` (por columna) | Edición limitada a la propia cuenta (`auth.uid() = id`). Anonimato respetado. |
| `band_events` | `SELECT` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | Visualización pública de fechas; gestión restringida a integrantes de la banda. |
| `band_photos` | `SELECT` | `SELECT`, `INSERT`, `DELETE` | Galería pública; subida y baja reservada a integrantes de la banda. |
| `band_follows` | Ninguno | `SELECT`, `INSERT`, `DELETE` | Consultas restringidas al propio usuario o miembros de la banda. Conteo público vía RPC. |
| `donations` | `SELECT` | `SELECT`, `INSERT` | Muro público filtrado a `is_public = true`. Donaciones registradas con `donor_id = auth.uid()`. |
| `app_config` | `SELECT` | `SELECT` | Configuración de solo lectura para la app (topes de donación y flags de demanda). |
| `app_admins` | Ninguno | `SELECT` | Listado interno de moderadores del colectivo para validación de permisos. |
| `reports` | Ninguno | `SELECT`, `INSERT`, `UPDATE (status)` | Creación abierta a usuarios autenticados; resolución restringida a administradores. |
| `play_events` | Ninguno | `SELECT`, `INSERT` | Registro de reproducciones para cálculo de estadísticas privadas de la banda. |

---

## 👥 Equipo de Desarrollo

- **Juan Manuel Atencio**
- **Francisco Navas**
- **Pablo Penoff**
- **Kevin Nieto**

**Cliente / Referente:** Colectivo StreamTunes (Kiwi Delmonte)  
**Materia / Marco:** Aplicaciones Móviles Multiplataforma / EGI (Noviembre 2026)

---

## 📄 Licencia

Este proyecto se distribuye bajo fines académicos y comunitarios para el Colectivo StreamTunes. Para detalles de uso, consultar con el equipo de desarrollo.
