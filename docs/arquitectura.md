# StreamTunes — Arquitectura y Modelo de Datos

> **Documento de Arquitectura de Software y Persistencia**  
> **Proyecto:** StreamTunes — Plataforma Comunitaria de Streaming Under  
> **Stack:** Flutter (PWA & Android) · Supabase (PostgreSQL 15, RLS, Storage, Realtime)  

---

## 1. Visión y Propuesta de Valor

StreamTunes es una plataforma de streaming y financiamiento directo para bandas independientes y música under. Su arquitectura desacopla el reproductor continuo de audio de la gestión de identidades y datos relacionales.

**Pilares del producto:**
- **Acceso libre y sin publicidad:** Escucha abierta sin costo ni suscripciones invasivas.
- **Autogestión de bandas:** Las bandas suben sus canciones, portadas y gestionan su perfil sin intermediarios ni agregadoras.
- **Sostenibilidad comunitaria:** Módulo de donaciones voluntarias con tope dinámico de gasto para prevenir abusos.
- **Catálogo transparente:** Priorización de lanzamientos auténticos y exploración directa por género y búsqueda, sin algoritmos opacos.
- **Modelo de seguridad robusto:** Políticas de seguridad a nivel de fila (RLS) en base de datos para garantizar la privacidad y autoría.

---

## 2. Modelo de Identidad: Usuario ≠ Banda

El sistema implementa una separación radical entre la **persona física** (cuenta y perfil) y la **entidad artística** (banda o colectivo musical). Una persona puede registrarse simplemente para escuchar o participar en una o varias bandas con roles diferenciados:

```
auth.users (Supabase Auth)
     │ 1:1
  profiles ──────────────< band_members >────────── bands
(la persona)                (rol: owner/member)     (perfil público)
     │                                                │
     ├─< playlists >─< playlist_songs >─ songs >──────┤
     ├─< donations >──────────────────────────────────┤
     └─< play_events >────────────────────────────────┘
```

### Roles y permisos
| Rol / Entidad | Identificador | Capacidades |
|---|---|---|
| **Visitante** | Anónimo (sin sesión) | Reproducir canciones de bandas aprobadas, ver perfiles públicos y explorar la Home. |
| **Oyente autenticado** | `profiles.id` | Todo lo anterior + crear playlists personales, donar a bandas, seguir artistas y denunciar contenido. |
| **Miembro de banda** | `band_members` (`member`) | Todo lo anterior + subir canciones (dentro del cupo permitido), editar bio/redes y acceder al panel privado de métricas. |
| **Dueño de banda** | `band_members` (`owner`) | Todo lo anterior + administrar integrantes de la banda. |
| **Moderador / Admin** | `app_admins` | Acceso a `AdminModerationView`, aprobación o suspensión de bandas y resolución de reportes de contenido. |

---

## 3. Arquitectura de la Aplicación Flutter

StreamTunes implementa una arquitectura en capas unidireccional y desacoplada, con gestión de estado basada en `ChangeNotifier` y proveedores globales de contexto (`InheritedNotifier`):

```
lib/
├── config/            # Constantes de negocio, cupos y flags de entorno (app_config, app_constants)
├── models/            # Entidades inmutables con serialización JSON (Band, Song, Profile, etc.)
├── repositories/
│   ├── interfaces/    # Contratos abstractos (AuthRepository, SongRepository, etc.)
│   ├── fake/          # Implementaciones en memoria (tests y modo demo offline USE_MOCK=true)
│   └── supabase/      # Implementaciones reales contra API REST / PostgREST de Supabase
├── services/          # Infraestructura (SupabaseService, AudioService, BackgroundUploadService, etc.)
├── view_models/       # Estado de vistas con ChangeNotifier (SessionViewModel, UploadViewModel, etc.)
├── views/             # Vistas de navegación y formularios adaptativos
└── widgets/           # Scopes globales (SessionScope, ReproductorScope) y componentes reutilizables
```

### 3.1 Doble Backend y Desacoplamiento (Criterio C1 / C3)
Para garantizar alta resiliencia durante demos o pruebas en entornos sin conectividad:
- La factoría `AppRepositories.create({useMock})` instancia implementaciones `Fake*` o `Supabase*` de forma transparente.
- Las vistas y los `ViewModels` dependen exclusivamente de las **interfaces de repositorio**, sin acoplamiento a llamadas de red directas.
- El modo offline (`USE_MOCK=true`) permite ejecutar toda la suite de pruebas automatizadas y la PWA sin conexión a internet.

### 3.2 Manejo de Estado y Scopes
- **`SessionScope` (`SessionViewModel`):** Centraliza la sesión del usuario, membresías de bandas activas y rol de administración.
- **`ReproductorScope` (`ReproductorViewModel`):** Controla el estado global de reproducción de audio, cola de temas, progreso y visualización de letras LRC sincronizadas.
- **`RepositoriesScope`:** Provee el contenedor de repositorios a la jerarquía de widgets sin recurrir a variables globales estáticas.

### 3.3 Capacidades del Dispositivo y Multiplataforma
Toda interacción dependiente del hardware o del sistema operativo está encapsulada en `DispositivoCapacidades`:
- **Audio e interrupciones:** Integración de `just_audio` con `audio_session`, respondiendo a eventos de foco de audio (pausa durante llamadas telefónicas o notificaciones exclusivas).
- **Subida de archivos:** `file_picker` para la selección de audio real y lectura de duración; `image_picker` para portadas fotográficas.
- **Notificaciones locales y background:** `flutter_local_notifications` en Android/iOS con notificación de publicación completada; respaldo inmediato con `SnackBar` in-app en navegadores web.

---

## 4. Esquema de Base de Datos en PostgreSQL (Supabase)

La persistencia de datos relacional se gestiona en PostgreSQL 15, organizado a través de migraciones versionadas en `supabase/migrations/`.

### 4.1 Tablas Principales
| Tabla | Descripción | Clave Primaria / Foráneas |
|---|---|---|
| `profiles` | Perfil del usuario autenticado | `id` (PK, references `auth.users.id`) |
| `app_admins` | Registro de moderadores del colectivo | `user_id` (PK, references `profiles.id`) |
| `app_config` | Parámetros dinámicos del sistema (topes de gasto, límites de reportes) | `key` (PK, text) |
| `bands` | Entidad de banda musical | `id` (PK, uuid), `created_by` (FK `profiles.id`), `status` (`pending`, `approved`, `suspended`) |
| `band_members` | Vínculo usuario-banda y roles | `(band_id, user_id)` (PK compuesta), `role` (`owner`, `member`) |
| `albums` | Álbumes o EPs de una banda | `id` (PK, uuid), `band_id` (FK `bands.id`) |
| `songs` | Pistas musicales y metadatos | `id` (PK, uuid), `band_id` (FK `bands.id`), `album_id` (FK `albums.id`), `lyrics_lrc` |
| `playlists` | Listas de reproducción de usuarios | `id` (PK, uuid), `user_id` (FK `profiles.id`) |
| `playlist_songs` | Temas agregados a una lista | `(playlist_id, song_id)` (PK compuesta) |
| `donations` | Registro de donaciones voluntarias | `id` (PK, uuid), `band_id` (FK `bands.id`), `donor_id` (FK `profiles.id`) |
| `play_events` | Registro de reproducciones para métricas | `id` (PK, uuid), `song_id` (FK `songs.id`), `band_id` (FK `bands.id`) |
| `band_daily_stats` | Agregados diarios de reproducción | `(band_id, day)` (PK compuesta) |
| `reports` | Denuncias comunitarias de contenido | `id` (PK, uuid), `reporter_id` (FK `profiles.id`) |
| `band_events` | Agenda de fechas y recitales | `id` (PK, uuid), `band_id` (FK `bands.id`) |
| `band_photos` | Galería fotográfica oficial | `id` (PK, uuid), `band_id` (FK `bands.id`) |
| `band_follows` | Seguimiento de bandas por oyentes | `(band_id, user_id)` (PK compuesta) |

---

## 5. Seguridad y Políticas de Acceso por Fila (RLS)

Todas las tablas cuentan con `row level security` habilitado de forma estricta. Ninguna vista o cliente anónimo puede realizar lecturas no autorizadas o mutaciones directas sobre datos protegidos:

### 5.1 Reglas Clave de Seguridad
1. **Bandas y Contenido Público:**
   - La lectura (`SELECT`) sobre `bands` está restringida a registros en estado `approved`, o bien a sus propios miembros creadores.
   - La inserción de canciones (`INSERT` en `songs`) exige que el usuario autenticado sea miembro activo de la banda correspondiente (`is_band_member(band_id)`).
2. **Control de Cupos por Trigger en Base de Datos:**
   - Triggers `check_band_song_limit` y `check_band_album_limit` validan a nivel de motor de base de datos que ninguna banda supere el tope de 20 temas o 2 álbumes.
3. **Mecanismo Anti-Copyright y Auto-Ocultación:**
   - Cada inserción en `reports` evalúa si el contenido alcanza el umbral de denuncias abiertas (`reports_to_hide`, por defecto 3). Al alcanzarse, la columna `hidden` se activa automáticamente hasta que un moderador la revise.
4. **Protección de Métricas Privadas:**
   - Las estadísticas detalladas de `play_events` y donaciones solo pueden ser consultadas por miembros autenticados de la respectiva banda o administradores del colectivo.
   - Las funciones RPC en servidor (`band_aggregated_stats`, `band_top_fans`) realizan agregaciones controladas respetando la privacidad del usuario (anonimizando oyentes que no hayan activado el consentimiento opt-in `is_public_profile`).

---

## 6. Almacenamiento en Supabase Storage

El almacenamiento binario se organiza en tres buckets dedicados:
- **`audio/`**: Archivos de sonido (`audio/mpeg`, `audio/mp4`, `audio/wav`). Tamaño máximo por archivo: 50 MB. Rutas organizadas como `<band_id>/<song_id>.mp3`.
- **`covers/`**: Portadas de canciones, álbumes y bandas (`image/jpeg`, `image/png`, `image/webp`). Tamaño máximo por archivo: 5 MB.
- **`stories/`**: Material visual de difusión temporal (`video/mp4`, `image/*`).

Las políticas de Storage restringen la subida de archivos únicamente a usuarios autenticados que pertenezcan a la banda titular del directorio (`auth.uid() in (select user_id from band_members where band_id = (storage.foldername(name))[1])`).
