# StreamTunes — Plan Maestro (Fase 2 → Supabase)

> Documento único para el equipo. Resume **qué es el proyecto, qué pidió el cliente, en qué estado está el código, qué problemas hay y qué tareas hacer** para separar *usuarios* de *bandas*, conectar **Supabase** y dejar la app más funcional e intuitiva.
> Si algo de este documento contradice un chat o un mensaje suelto, **manda este documento** (y se actualiza con un PR).

**Equipo:** Juan Manuel Atencio · Francisco Navas · Pablo Penoff · Kevin Nieto
**Cliente:** Colectivo StreamTunes (referente: Kiwi Delmonte)
**Stack:** Flutter (PWA web + móvil) · `ChangeNotifier` · Supabase (a integrar)

---

## Índice

1. [Qué es StreamTunes](#1-qué-es-streamtunes)
2. [Requerimientos del cliente (entrevistas)](#2-requerimientos-del-cliente-entrevistas)
3. [Estado actual del código](#3-estado-actual-del-código)
4. [Mapa contra la grilla de evaluación (EGI)](#4-mapa-contra-la-grilla-de-evaluación-egi)
5. [El problema: perfiles mezclados](#5-el-problema-perfiles-mezclados)
6. [Propuesta: usuario ≠ banda](#6-propuesta-usuario--banda)
7. [Base de datos en Supabase](#7-base-de-datos-en-supabase)
8. [Cambios en la app Flutter](#8-cambios-en-la-app-flutter)
9. [Mejoras de funcionalidad e intuitividad (UX)](#9-mejoras-de-funcionalidad-e-intuitividad-ux)
10. [Plan de tareas por fases](#10-plan-de-tareas-por-fases)
11. [Decisiones pendientes con Kiwi](#11-decisiones-pendientes-con-kiwi)
12. [Riesgos y costos](#12-riesgos-y-costos)
13. [Guía de trabajo del equipo](#13-guía-de-trabajo-del-equipo)
14. [Anexo: reglas y prompts para la IA (Antigravity)](#14-anexo-reglas-y-prompts-para-la-ia-antigravity)

---

## 1. Qué es StreamTunes

Plataforma de streaming de música **para bandas independientes (under)**, pensada como alternativa a las plataformas grandes que "pagan centavos por reproducción". Se lanza primero como **PWA** (funciona en celu y compu sin pasar por tiendas) para no pagar las cuotas de Apple/Google.

**Propuesta de valor (palabras de Kiwi):**
- Gratis y **sin anuncios** para quien escucha. Nada de "pagá para seguir escuchando".
- Las bandas suben su música directo, sin intermediarios.
- **Botón de donaciones** como motor económico ("esa es la posta").
- Home con **últimos lanzamientos**, no un algoritmo que decide por vos.
- Estética oscura, mezcla de **Spotify (simpleza) + Bandcamp (espíritu independiente) + SoundCloud (comunidad)**.

---

## 2. Requerimientos del cliente (entrevistas)

### 2.1 Primera entrevista (resumen)
- Colectivo de bandas independientes cansadas de que las plataformas grandes paguen centavos.
- Funciones: perfil de artista, subida de canciones y álbumes, listas de reproducción, escucha gratuita sin anuncios.
- Preocupación central: **el costo** de almacenar y transmitir audio. "Primero hacemos que funcione y vemos cómo se paga."
- Quieren **estadísticas** por canción: cuántas reproducciones y **desde qué lugar**.

### 2.2 Segunda entrevista: decisiones ya tomadas por Kiwi

| Tema | Decisión de Kiwi |
|---|---|
| Sostenibilidad | **Sin freemium.** Solo botón de donaciones. |
| Límites de subida | Aceptan **2 álbumes o 20 temas por banda**, pero aclarando que es **"por ahora"**, no para siempre. |
| Calidad de audio | **MP3 a 192 kbps**, sin problema. |
| Estadísticas | **Una vez al día** alcanza ("ayer te escucharon acá"). Tiempo real, a futuro. |
| Filtro de registro (no subir música de terceros) | **Les preocupa mucho** y no lo pensaron. Piden ideas para filtrarlo en el registro. |
| Plataforma | **PWA gratis** primero; tiendas oficiales cuando junten plata. |
| Picos de tráfico | Prefieren **tope de gastos**: que la app avise "mucha demanda, aguanten un toque" antes que llegue una factura. |
| Mantenimiento | No tienen a nadie técnico: **cotizar abono mensual**. |
| Moderación | Pueden armar **turnos entre los del Colectivo** para revisar reportes; piden herramientas que filtren antes. |
| Dominio y hosting | No tienen nada comprado: lo gestiona el equipo y después se transfiere a su nombre. |
| Offline | **No es prioridad** (versión 2). |
| Pantalla principal | **Últimos lanzamientos.** |
| Reproductor | **Barra fija abajo**, para seguir mirando perfiles mientras suena. |
| Perfil de artista | Foto de portada, bio corta, redes, **canciones más escuchadas arriba de todo**. Estadísticas visibles **solo para el artista**. |
| Subida | **Simple**: archivo, título y portada. Nada de metadata compleja. |
| Playlists | Se arman **desde cualquier lado**, no solo desde "Mi Biblioteca". |

### 2.3 Preguntas técnicas planteadas a Kiwi (a confirmar)
Ver [sección 11](#11-decisiones-pendientes-con-kiwi): cámara para historias de 15 s, ranking de oyentes, muro público de donaciones, reproductor en pantalla completa, subida en segundo plano, reanudar tras una llamada, diseño distinto en compu.

---

## 3. Estado actual del código

### 3.1 Arquitectura (ya implementada)
```
lib/
├── data/            mock_data.dart            (datos simulados → se reemplaza por Supabase)
├── models/          song, artist, playlist, donation, metricas_artista, playback_record
├── repositories/    music_repository.dart
├── services/        dispositivo_capacidades, donaciones_service, background_upload_service
├── view_models/     reproductor, library, upload, artist_detail  (todos ChangeNotifier)
├── views/           home, library, upload, artist_detail, main_navigation_shell
├── widgets/         player_bar, now_playing_modal, song_tile, reproductor_scope, library_scope
├── theme/           app_theme.dart
└── main.dart
```

### 3.2 Reglas de arquitectura (obligatorias)
1. **Capas** estrictas: `models → repositories → services → view_models → views/widgets`. Las vistas **no** leen datos directamente.
2. Estado solo con `ChangeNotifier` + `ListenableBuilder` + los `InheritedNotifier` globales (`ReproductorScope`, `LibraryScope`). **Prohibido prop-drilling** y paquetes de estado externos (provider, riverpod).
3. **Prohibido** `kIsWeb`, `Platform.*`, `defaultTargetPlatform` en vistas y view models. Va en `DispositivoCapacidades` o servicios.
4. Asincronía: `Future`/`async-await`; cálculos pesados con `Isolate.run` (nativo) / `compute` (web) encapsulado; `Streams` con `cancel()` en `dispose()`.
5. Calidad: `dart format .`, `flutter analyze` sin avisos y `flutter test` en verde antes de cada merge.

### 3.3 Ya resuelto en la rama `fase2-mvp`
- [x] Notificación en segundo plano: el isolate de Workmanager inicializa el plugin antes de notificar.
- [x] Permiso `POST_NOTIFICATIONS` (Android 13+) en manifest + pedido en runtime.
- [x] Simulación de donaciones en vivo con `Stream` (se detiene y cancela en `dispose`).
- [x] Prop-drilling eliminado; carpeta `state/` borrada; getters duplicados del reproductor eliminados.
- [x] `kIsWeb` fuera del ViewModel (`DispositivoCapacidades.ejecutarComputoPesado`).
- [x] Canciones más escuchadas arriba del perfil; estadísticas solo para el dueño (simulado).
- [x] Botón "Reportar perfil" y aviso de topes de gasto (visuales).
- [x] Límite de 2 álbumes / 20 temas **validado** en `UploadViewModel`.
- [x] Proyecto renombrado a `streamtunes` (paquete Dart, `namespace` y `applicationId` = `com.streamtunes.app`, `MainActivity` movida).
- [x] 10 tests en `test/widget_test.dart`.

### 3.4 Lo que sigue siendo simulado o flojo
| Área | Realidad actual |
|---|---|
| Datos | Todo en memoria (`MockData`); se pierde al recargar. |
| Cuentas | No hay login. "Artista logueado" = constante `artist_1`. |
| Audio | El reproductor **no reproduce audio real**: avanza un `Timer`. |
| Subida | No sube archivos: simula el nombre del MP3 y programa una notificación. |
| Donaciones | Simuladas; no hay pago real (MercadoPago a futuro). |
| Estadísticas | Se generan 50.000 registros falsos en el cliente. |
| Cámara en web | `tieneCamara` da `false` en web (contradice lo prometido a Kiwi). |
| Llamadas | Pausa en `inactive`/`paused`, pero **no reanuda** (decisión abierta). |
| Capas | Algunas vistas aún leen `MockData` directo (rompe C1). |

---

## 4. Mapa contra la grilla de evaluación (EGI)

La grilla tiene 18 criterios (A1–G1) con escala 0–3 (3 Logrado · 2 En proceso · 1 Inicial · 0 No presenta). Máximo: 54 puntos. La planilla trae una columna con fecha **19/11**.

| Criterio | Estado | Qué falta / cómo lo cubre este plan |
|---|---|---|
| **A1** Alcance y respuesta al cliente | 🟡 Parcial | Perfiles separados, filtro de registro real, datos persistentes. Ver §6–§10. |
| **B1** Interfaz: widgets y composición | 🟢 Bien | Mejoras de UX (§9). |
| **B2** Estado y ciclo de vida | 🟢 Bien | Sumar `SessionViewModel`; mantener `dispose()` correcto. |
| **B3** Interacción y navegación | 🟡 Parcial | Navegación según sesión/rol, pantallas de login y panel de banda. |
| **B4** Configuración multiplataforma | 🟡 Parcial | Config por entorno (`--dart-define`), diseño adaptativo del perfil en compu. |
| **C1** Arquitectura en capas | 🟡 Parcial | Repositorios con interfaz; sacar `MockData` de vistas/widgets. |
| **C2** Código limpio y herramientas | 🟢 Bien | `dart format`, `flutter analyze` en cada PR. |
| **C3** Refactoring | 🟢 Bien | Dejar evidencia en commits/PRs (antes → después). |
| **C4** Pruebas | 🟡 Parcial | Fakes de repositorios, tests de sesión/roles/limites. |
| **D1** Capacidades y políticas | 🟡 Parcial | Arreglar cámara en web; políticas por rol. |
| **D2** Future y async/await | 🟢 Bien | Repositorios Supabase 100 % async. |
| **D3** Streams e Isolates | 🟢 Bien | Realtime de donaciones como `Stream`. |
| **E1** Notificaciones | 🟢 Bien | Probar en celu real. |
| **E2** Segundo plano | 🟡 Parcial | Subida real a Storage con Workmanager; probar en dispositivo. |
| **E3** Eventos del sistema | 🟡 Parcial | `audio_session` para llamadas + decisión de reanudar. |
| **F1** Persistencia, APIs y cámara | 🔴→🟢 | **Supabase** = persistencia + API; cámara con `image_picker`. |
| **F2** Testing en dispositivo real y publicación | 🔴 Pendiente | Deploy del PWA + prueba en celu (§10, Fase 7). |
| **G1** Demo y defensa | 🔴 Pendiente | Guion de demo + modo mock de respaldo (§10, Fase 7). |

---

## 5. El problema: perfiles mezclados

Hoy `Artist` representa a la vez **a la persona que inicia sesión** y **al perfil público de la banda**. Eso genera mezclas concretas:

- `esDuenoDelPerfil` y `artistaLogueadoId` son parches: no existe el concepto de "quién soy".
- Cualquiera puede subir música y la sube "como `artist_1`".
- Un oyente y un músico ven exactamente la misma app.
- Un colectivo con **varias bandas** (o una banda con **varios integrantes**) no se puede modelar.
- No hay forma de moderar: una banda "falsa" aparece igual que una real.
- Las estadísticas "privadas" se protegen solo en la UI, no en los datos.

---

## 6. Propuesta: usuario ≠ banda

**Una sola cuenta por persona** (no hay "tipo de cuenta músico" vs "tipo oyente"). Lo que cambia es la **relación** entre la persona y las bandas.

```
auth.users (Supabase)
     │ 1:1
profiles  ──────────────< band_members >────────── bands
(la persona)                (rol: owner/member)     (perfil público)
     │                                                │
     ├─< playlists >─< playlist_songs >─ songs >──────┤
     ├─< donations >──────────────────────────────────┤
     └─< play_events >────────────────────────────────┘
```

| Concepto | Qué es | Qué puede hacer |
|---|---|---|
| **Visitante** (sin cuenta) | Anónimo | Escuchar y ver perfiles públicos de bandas aprobadas. |
| **Usuario** (`profiles`) | Cualquier persona con cuenta | Todo lo anterior + playlists, donar, reportar, seguir bandas. |
| **Miembro de banda** (`band_members`) | Usuario vinculado a una banda | Todo lo anterior + subir música, editar el perfil de la banda, ver sus estadísticas y donaciones. |
| **Owner de banda** | Miembro con rol `owner` | Todo lo anterior + invitar/quitar miembros. |
| **Moderador/admin** (`app_admins`) | Gente del Colectivo | Aprobar/suspender bandas y resolver reportes. |

**Regla de oro:** "ser dueño del perfil" deja de ser un flag y pasa a ser una consulta: *¿existe una fila en `band_members` con mi `user_id` y esa `band_id`?* Esto lo valida **la base de datos (RLS)**, no solo la UI.

**Cómo responde esto al filtro de registro que pidió Kiwi:**
1. Cualquiera puede crear una banda, pero nace en estado `pending`.
2. Una banda `pending` **no aparece en público** y no puede publicar.
3. Un moderador del Colectivo la revisa (Instagram, links, demo) y la pasa a `approved`.
4. Los reportes (`reports`) permiten suspender (`suspended`) bandas o ocultar canciones.

Es un filtro **humano pero liviano**, coherente con los turnos de revisión que ofreció el Colectivo.

---

## 7. Base de datos en Supabase

> ⚠️ El SQL de esta sección es una **propuesta lista para probar**, pero no fue ejecutado. Probarlo primero en un **proyecto Supabase de prueba**, revisar errores y recién ahí pasarlo al proyecto real. Guardarlo en el repo como migraciones (`supabase/migrations/…`).

### 7.1 Tablas

| Tabla | Para qué | Campos clave |
|---|---|---|
| `profiles` | La persona (1:1 con `auth.users`) | `id`, `display_name`, `avatar_url` |
| `app_admins` | Moderadores | `user_id` |
| `app_config` | Límites configurables ("por ahora") | `key`, `value` |
| `bands` | Perfil público de la banda | `name`, `slug`, `bio`, `genre`, `location`, `cover_url`, `social_links`, `donation_goal`, `donations_collected`, `status` |
| `band_members` | Quién maneja cada banda | `band_id`, `user_id`, `role` |
| `albums` | Álbumes | `band_id`, `title`, `cover_url` |
| `songs` | Temas | `band_id`, `album_id`, `title`, `audio_path`, `duration_s`, `play_count` |
| `playlists`, `playlist_songs` | Listas del usuario | `user_id`, `name`, `is_public` |
| `donations` | Donaciones | `band_id`, `donor_id`, `amount`, `message`, `is_public` |
| `play_events` | Cada reproducción | `song_id`, `band_id`, `user_id`, `seconds_listened`, `city` |
| `band_daily_stats` | Estadísticas por día (precalculadas) | `band_id`, `day`, `plays`, `minutes`, `unique_listeners` |
| `stories` | Videos cortos (≤15 s) | `band_id`, `video_path`, `duration_s` |
| `reports` | Reportes de contenido | `reporter_id`, `band_id`/`song_id`, `reason`, `status` |

### 7.2 Esquema (SQL)

```sql
-- =========================================================
-- 0. Tipos
-- =========================================================
create type public.band_status   as enum ('pending', 'approved', 'suspended');
create type public.member_role   as enum ('owner', 'member');
create type public.report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');

-- =========================================================
-- 1. Personas y configuración
-- =========================================================
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 50),
  avatar_url   text,
  created_at   timestamptz not null default now()
);

create table public.app_admins (
  user_id uuid primary key references public.profiles(id) on delete cascade
);

-- Límites "por ahora" (Kiwi): se cambian con un UPDATE, sin tocar código
create table public.app_config (
  key   text primary key,
  value integer not null
);
insert into public.app_config (key, value) values
  ('max_songs_per_band',  20),
  ('max_albums_per_band',  2),
  ('max_donation_ars',  5000);

-- Crear el perfil automáticamente al registrarse
create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =========================================================
-- 2. Bandas y membresías
-- =========================================================
create table public.bands (
  id                  uuid primary key default gen_random_uuid(),
  slug                text not null unique,
  name                text not null check (char_length(name) between 2 and 60),
  bio                 text,
  genre               text,
  location            text,
  cover_url           text,
  social_links        jsonb not null default '{}'::jsonb,
  donation_goal       numeric(12,2) not null default 0,
  donations_collected numeric(12,2) not null default 0,
  status              public.band_status not null default 'pending',
  created_by          uuid not null references public.profiles(id),
  created_at          timestamptz not null default now()
);

create table public.band_members (
  band_id    uuid not null references public.bands(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       public.member_role not null default 'member',
  created_at timestamptz not null default now(),
  primary key (band_id, user_id)
);
create index on public.band_members (user_id);

-- Funciones auxiliares para RLS
create function public.is_band_member(p_band uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.band_members
    where band_id = p_band and user_id = auth.uid()
  );
$$;

create function public.is_band_owner(p_band uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.band_members
    where band_id = p_band and user_id = auth.uid() and role = 'owner'
  );
$$;

create function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.app_admins where user_id = auth.uid());
$$;

-- Quien crea la banda queda como owner
create function public.add_creator_as_owner()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.band_members (band_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end $$;

create trigger on_band_created
  after insert on public.bands
  for each row execute function public.add_creator_as_owner();

-- =========================================================
-- 3. Música
-- =========================================================
create table public.albums (
  id         uuid primary key default gen_random_uuid(),
  band_id    uuid not null references public.bands(id) on delete cascade,
  title      text not null,
  cover_url  text,
  created_at timestamptz not null default now(),
  unique (band_id, title)
);

create table public.songs (
  id         uuid primary key default gen_random_uuid(),
  band_id    uuid not null references public.bands(id) on delete cascade,
  album_id   uuid references public.albums(id) on delete set null,
  title      text not null,
  genre      text,
  audio_path text not null,                    -- ruta en Storage: {band_id}/{song_id}.mp3
  duration_s integer not null check (duration_s > 0),
  play_count bigint not null default 0,
  hidden     boolean not null default false,   -- lo puede ocultar un moderador
  created_at timestamptz not null default now()
);
create index on public.songs (band_id);
create index on public.songs (created_at desc);   -- "últimos lanzamientos"

-- Límites reales (no se pueden saltear desde la app)
create function public.enforce_song_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_max int; v_actual int;
begin
  select value into v_max from public.app_config where key = 'max_songs_per_band';
  select count(*) into v_actual from public.songs where band_id = new.band_id;
  if v_actual >= v_max then
    raise exception 'Límite de subida alcanzado: máximo % temas por banda.', v_max
      using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger songs_limit before insert on public.songs
  for each row execute function public.enforce_song_limit();

create function public.enforce_album_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_max int; v_actual int;
begin
  select value into v_max from public.app_config where key = 'max_albums_per_band';
  select count(*) into v_actual from public.albums where band_id = new.band_id;
  if v_actual >= v_max then
    raise exception 'Límite de subida alcanzado: máximo % álbumes por banda.', v_max
      using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger albums_limit before insert on public.albums
  for each row execute function public.enforce_album_limit();

-- =========================================================
-- 4. Playlists
-- =========================================================
create table public.playlists (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  name        text not null,
  description text,
  is_public   boolean not null default false,
  created_at  timestamptz not null default now()
);

create table public.playlist_songs (
  playlist_id uuid not null references public.playlists(id) on delete cascade,
  song_id     uuid not null references public.songs(id)     on delete cascade,
  position    integer not null default 0,
  added_at    timestamptz not null default now(),
  primary key (playlist_id, song_id)
);

-- =========================================================
-- 5. Donaciones, reproducciones y estadísticas
-- =========================================================
create table public.donations (
  id         uuid primary key default gen_random_uuid(),
  band_id    uuid not null references public.bands(id) on delete cascade,
  donor_id   uuid not null references public.profiles(id),
  amount     numeric(12,2) not null check (amount > 0),
  currency   text not null default 'ARS',
  message    text check (char_length(message) <= 200),
  is_public  boolean not null default true,          -- ¿aparece en el muro público?
  created_at timestamptz not null default now()
);
create index on public.donations (band_id, created_at desc);

-- Tope por donación (control de gasto) + acumulado de la banda
create function public.on_donation_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_max int;
begin
  select value into v_max from public.app_config where key = 'max_donation_ars';
  if new.amount > v_max then
    raise exception 'El monto máximo por donación es $% ARS.', v_max using errcode = 'P0001';
  end if;
  update public.bands
     set donations_collected = donations_collected + new.amount
   where id = new.band_id;
  return new;
end $$;
create trigger donations_after_insert before insert on public.donations
  for each row execute function public.on_donation_insert();

create table public.play_events (
  id               bigint generated always as identity primary key,
  song_id          uuid not null references public.songs(id) on delete cascade,
  band_id          uuid not null references public.bands(id) on delete cascade,
  user_id          uuid references public.profiles(id) on delete set null,
  seconds_listened integer not null check (seconds_listened >= 0),
  city             text,
  created_at       timestamptz not null default now()
);
create index on public.play_events (band_id, created_at);

create table public.band_daily_stats (
  band_id          uuid not null references public.bands(id) on delete cascade,
  day              date not null,
  plays            integer not null default 0,
  minutes          integer not null default 0,
  unique_listeners integer not null default 0,
  primary key (band_id, day)
);

-- Recalcula un día completo (se programa cada madrugada)
create function public.refresh_band_daily_stats(p_day date default (current_date - 1))
returns void language sql security definer set search_path = public as $$
  insert into public.band_daily_stats (band_id, day, plays, minutes, unique_listeners)
  select band_id, p_day, count(*), coalesce(sum(seconds_listened), 0) / 60,
         count(distinct user_id)
  from public.play_events
  where (created_at at time zone 'America/Argentina/Buenos_Aires')::date = p_day
  group by band_id
  on conflict (band_id, day) do update
    set plays = excluded.plays,
        minutes = excluded.minutes,
        unique_listeners = excluded.unique_listeners;
$$;

-- Ranking de oyentes (solo lo puede pedir un miembro de esa banda)
create function public.band_top_listeners(p_band uuid, p_days int default 30)
returns table (user_id uuid, display_name text, minutes bigint)
language sql stable security definer set search_path = public as $$
  select pe.user_id, p.display_name, sum(pe.seconds_listened) / 60
  from public.play_events pe
  join public.profiles p on p.id = pe.user_id
  where pe.band_id = p_band
    and public.is_band_member(p_band)
    and pe.created_at >= now() - make_interval(days => p_days)
  group by pe.user_id, p.display_name
  order by 3 desc
  limit 10;
$$;

-- Programar (habilitar la extensión pg_cron desde el dashboard). 06:00 UTC = 03:00 ART
-- select cron.schedule('stats-diarias', '0 6 * * *', $$select public.refresh_band_daily_stats()$$);

-- =========================================================
-- 6. Historias y reportes
-- =========================================================
create table public.stories (
  id         uuid primary key default gen_random_uuid(),
  band_id    uuid not null references public.bands(id) on delete cascade,
  video_path text not null,
  duration_s integer not null check (duration_s between 1 and 15),
  created_at timestamptz not null default now()
);

create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id),
  band_id     uuid references public.bands(id) on delete cascade,
  song_id     uuid references public.songs(id) on delete cascade,
  reason      text not null check (char_length(reason) between 5 and 500),
  status      public.report_status not null default 'open',
  created_at  timestamptz not null default now(),
  check (band_id is not null or song_id is not null)
);
```

### 7.3 Seguridad (RLS)

Activar RLS en **todas** las tablas. Sin políticas, nadie accede a nada.

```sql
alter table public.profiles         enable row level security;
alter table public.app_admins       enable row level security;
alter table public.app_config       enable row level security;
alter table public.bands            enable row level security;
alter table public.band_members     enable row level security;
alter table public.albums           enable row level security;
alter table public.songs            enable row level security;
alter table public.playlists        enable row level security;
alter table public.playlist_songs   enable row level security;
alter table public.donations        enable row level security;
alter table public.play_events      enable row level security;
alter table public.band_daily_stats enable row level security;
alter table public.stories          enable row level security;
alter table public.reports          enable row level security;

-- profiles: cualquiera logueado ve nombres; cada uno edita el suyo
create policy "perfiles visibles" on public.profiles for select to authenticated using (true);
create policy "editar mi perfil"  on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- app_config: lectura pública, escritura solo desde el dashboard
create policy "config legible" on public.app_config for select using (true);

-- bands: público ve las aprobadas; miembros y admins ven las suyas
create policy "ver bandas" on public.bands for select
  using (status = 'approved' or public.is_band_member(id) or public.is_admin());
create policy "crear banda" on public.bands for insert to authenticated
  with check (created_by = auth.uid() and status = 'pending');
create policy "editar banda (owner)" on public.bands for update to authenticated
  using (public.is_band_owner(id) or public.is_admin())
  with check (public.is_band_owner(id) or public.is_admin());
-- (el cambio de status solo lo hacen admins: validarlo con un trigger o RPC)

-- band_members
create policy "ver miembros" on public.band_members for select to authenticated
  using (user_id = auth.uid() or public.is_band_member(band_id));
create policy "owner agrega miembros" on public.band_members for insert to authenticated
  with check (public.is_band_owner(band_id));
create policy "owner quita miembros" on public.band_members for delete to authenticated
  using (public.is_band_owner(band_id) or user_id = auth.uid());

-- albums / songs / stories: público si la banda está aprobada; escribe solo la banda
create policy "ver albums" on public.albums for select using (
  exists (select 1 from public.bands b where b.id = band_id and b.status = 'approved')
  or public.is_band_member(band_id));
create policy "banda gestiona albums" on public.albums for all to authenticated
  using (public.is_band_member(band_id)) with check (public.is_band_member(band_id));

create policy "ver songs" on public.songs for select using (
  (not hidden and exists (select 1 from public.bands b where b.id = band_id and b.status = 'approved'))
  or public.is_band_member(band_id) or public.is_admin());
create policy "banda gestiona songs" on public.songs for all to authenticated
  using (public.is_band_member(band_id)) with check (public.is_band_member(band_id));

create policy "ver stories" on public.stories for select using (
  exists (select 1 from public.bands b where b.id = band_id and b.status = 'approved')
  or public.is_band_member(band_id));
create policy "banda gestiona stories" on public.stories for all to authenticated
  using (public.is_band_member(band_id)) with check (public.is_band_member(band_id));

-- playlists: cada usuario las suyas (o públicas)
create policy "ver playlists" on public.playlists for select
  using (is_public or user_id = auth.uid());
create policy "gestionar mis playlists" on public.playlists for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "ver canciones de playlist" on public.playlist_songs for select using (
  exists (select 1 from public.playlists p
          where p.id = playlist_id and (p.is_public or p.user_id = auth.uid())));
create policy "gestionar canciones de mis playlists" on public.playlist_songs for all to authenticated
  using (exists (select 1 from public.playlists p where p.id = playlist_id and p.user_id = auth.uid()))
  with check (exists (select 1 from public.playlists p where p.id = playlist_id and p.user_id = auth.uid()));

-- donaciones: donar logueado; ver las públicas, las propias y las de mi banda
create policy "donar" on public.donations for insert to authenticated
  with check (donor_id = auth.uid());
create policy "ver donaciones" on public.donations for select
  using (is_public or donor_id = auth.uid() or public.is_band_member(band_id));

-- reproducciones y estadísticas: se insertan solas; solo la banda las lee
create policy "registrar reproduccion" on public.play_events for insert to authenticated
  with check (user_id = auth.uid());
create policy "banda ve sus reproducciones" on public.play_events for select to authenticated
  using (public.is_band_member(band_id));
create policy "banda ve sus stats" on public.band_daily_stats for select to authenticated
  using (public.is_band_member(band_id));   -- ← reemplaza a esDuenoDelPerfil

-- reportes
create policy "reportar" on public.reports for insert to authenticated
  with check (reporter_id = auth.uid());
create policy "ver reportes" on public.reports for select to authenticated
  using (reporter_id = auth.uid() or public.is_admin());
create policy "admin resuelve reportes" on public.reports for update to authenticated
  using (public.is_admin());
```

> 📝 **Pendiente de endurecer:** (a) que el cambio de `bands.status` solo lo haga un admin (trigger o función RPC `approve_band`), (b) que la app no pueda inflar `play_count`/`donations_collected` a mano. Anotar como tarea de la Fase 1.

### 7.4 Storage (archivos)

| Bucket | Contenido | Lectura | Escritura |
|---|---|---|---|
| `audio` | MP3 192 kbps | Pública | Solo miembros de la banda (carpeta = `band_id`) |
| `covers` | Portadas y fotos de banda | Pública | Solo miembros |
| `stories` | Videos ≤15 s | Pública | Solo miembros |

Convención de rutas: `{band_id}/{archivo}`. Ejemplo de política:

```sql
create policy "miembros suben audio" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'audio'
    and public.is_band_member(((storage.foldername(name))[1])::uuid)
  );
```
Repetir para `covers` y `stories`, y para `update`/`delete`.

### 7.5 Realtime
Activar *Realtime* sobre `donations`. La app escucha inserciones filtradas por `band_id`; así el `Stream` de donaciones deja de ser simulado y **el ViewModel casi no cambia**.

### 7.6 Estadísticas: cómo cambia el Isolate
- **Antes:** el celu genera y procesa 50.000 registros falsos.
- **Después:** `pg_cron` llena `band_daily_stats` cada madrugada (alineado con "una vez al día" de Kiwi). La app lee filas ya agregadas.
- El `Isolate`/`compute` se conserva para **procesar en el cliente** series largas (ej. armar gráficos de 90 días o ranking), de modo que el criterio D3 sigue cubierto de forma real.

### 7.7 Datos de ejemplo
Crear `supabase/seed.sql` con: 3 usuarios de prueba, 2 bandas `approved`, 1 `pending`, 5 canciones, 2 playlists y 1 admin. Sirve para la demo y para que todos trabajen con los mismos datos.

---

## 8. Cambios en la app Flutter

### 8.1 Dependencias nuevas
| Paquete | Para qué |
|---|---|
| `supabase_flutter` | Auth, base, Storage y Realtime |
| `just_audio` | **Reproducción de audio real** (hoy es simulada) |
| `audio_session` | Interrupciones (llamadas, auriculares) → criterio **E3** |
| `file_picker` | Elegir el MP3 real al subir |

> Las claves de Supabase van por `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`. **Nunca** commitear claves ni usar la `service_role` en la app.

### 8.2 Estructura propuesta
```
lib/
├── config/            app_config.dart            (lee --dart-define)
├── models/            profile, band, band_member, song, album, playlist, donation, ...
├── repositories/
│   ├── interfaces/    auth_repository, band_repository, song_repository,
│   │                  playlist_repository, donation_repository, stats_repository
│   ├── supabase/      implementaciones reales
│   └── fake/          implementaciones en memoria (tests + modo demo)
├── services/          supabase_service, storage_service, dispositivo_capacidades,
│                      background_upload_service, audio_service
├── view_models/       session_view_model (NUEVO), auth_view_model, band_dashboard_vm,
│                      band_public_vm, upload_vm, reproductor_vm, library_vm, ...
├── views/             auth/ (login, registro), home, library, profile (usuario),
│                      band_public (perfil público), band_dashboard (panel), band_create, upload
└── widgets/           session_scope (NUEVO), player_bar, song_tile, ...
```

### 8.3 `SessionViewModel` (la pieza clave)
`ChangeNotifier` expuesto con un `SessionScope` (`InheritedNotifier`, igual que `ReproductorScope`). Mantiene:
- `profile` (la persona; `null` si es visitante)
- `myBands` (bandas donde soy miembro) y `activeBand` (con cuál estoy trabajando)
- `isLoggedIn`, `isMemberOf(bandId)`, `isOwnerOf(bandId)`, `isAdmin`

Reemplaza a `MockData.artistaLogueadoId` y al flag `esDuenoDelPerfil`.

### 8.4 Repositorios con interfaz (para no romper los tests)
Cada repositorio tiene una **interfaz abstracta** y dos implementaciones: `Supabase…` y `Fake…`. El `main.dart` elige según `--dart-define=USE_MOCK=true`.
- Los **tests siguen corriendo sin internet** con los fakes.
- Para la **defensa** hay un modo demo de respaldo si falla el wifi.

### 8.5 Mapa de migración (antes → después)

| Hoy | Después |
|---|---|
| `MockData` | `Fake*Repository` (tests/demo) + `Supabase*Repository` (real) |
| `Artist` | `Band` (público) + `Profile` (persona) |
| `artistaLogueadoId` / `esDuenoDelPerfil` | `SessionViewModel.isMemberOf(band.id)` |
| `DonacionesService` (Timer simulado) | Realtime sobre `donations` → `Stream<Donation>` |
| `UploadViewModel` (`artistId` fijo) | Usa `session.activeBand`; sube a Storage |
| `calcularEstadisticasIsolate` (50k falsos) | Lee `band_daily_stats` y `band_top_listeners` |
| Reproductor con `Timer` | `just_audio` + `audio_session` |
| "Reportar perfil" (SnackBar) | Inserta en `reports` |

### 8.6 Navegación según rol

```
Visitante:   Inicio · Explorar · Playlists(🔒 login) · Perfil(🔒 login)
Usuario:     Inicio · Explorar · Playlists · Perfil
Con banda:   Inicio · Explorar · Playlists · Mi banda · Perfil
```
- **Mi banda** (panel): subir música, editar perfil público, ver estadísticas y donaciones recientes, gestionar integrantes.
- Pantallas que requieren sesión redirigen a *Login* y vuelven al punto de origen.

---

## 9. Mejoras de funcionalidad e intuitividad (UX)

**Principio:** que un músico under suba su primer tema en menos de 1 minuto y que un oyente llegue a música sonando en 2 toques.

### 9.1 Onboarding y cuentas
- [ ] Registro corto: email + contraseña + nombre. Opción de entrar como visitante.
- [ ] Después del registro, una sola pregunta: **"¿Querés escuchar o subir tu banda?"** (no define tipo de cuenta; solo guía el siguiente paso).
- [ ] "Crear mi banda" en 3 pasos: nombre/género/ciudad → bio y redes → portada. Queda `pending` con mensaje claro: "Te avisamos cuando la aprueben".
- [ ] Estado de la banda visible en el panel (pendiente / aprobada / suspendida) con explicación.

### 9.2 Oyentes
- [ ] **Buscador** de bandas y temas + filtro por género (ya existe la lista `genres` en los datos de ejemplo).
- [ ] **Seguir bandas** y una sección "Novedades de las bandas que seguís".
- [ ] "Agregar a playlist" accesible **desde el reproductor completo** y desde cualquier lista (pedido de Kiwi), con opción "Nueva playlist" en el mismo diálogo.
- [ ] Reproductor en pantalla completa con portada grande, cola y barra de progreso arrastrable (la base ya existe en `now_playing_modal`).
- [ ] Estados vacíos amigables ("Todavía no tenés playlists. ¡Armá la primera!") en vez de pantallas en blanco.
- [ ] Indicador de carga y de error con botón "Reintentar" (hoy no hay manejo de red).

### 9.3 Bandas
- [ ] **Panel "Mi banda"** con tarjetas: reproducciones de ayer, donaciones de la semana, último tema, accesos rápidos.
- [ ] Subida guiada en un solo formulario: archivo → título → portada → publicar (sin metadata extra, como pidió Kiwi), con **contador de cupo** ("12/20 temas · 1/2 álbumes").
- [ ] Barra de progreso de subida real + aviso por notificación al terminar (Workmanager).
- [ ] Estadísticas con gráfico simple (últimos 7/30 días), ranking de oyentes y dónde escuchan (ciudad).
- [ ] Muro de donaciones en vivo con animación (si Kiwi lo confirma).

### 9.4 Donaciones y control de gasto
- [ ] Montos sugeridos + monto libre hasta el tope; mensaje opcional; checkbox "mostrar en el muro público".
- [ ] El aviso "Estamos con alta demanda – topes de gasto activos" debe ser un **estado real** (por ejemplo `app_config.spend_cap_active`) y no un cartel fijo.
- [ ] Integración de pago real (MercadoPago) como **etapa posterior**; en el MVP se mantiene el flujo simulado, aclarándolo en la demo.

### 9.5 Moderación
- [ ] "Reportar" abre un formulario corto (motivo) y guarda en `reports`.
- [ ] Vista **admin** simple para el Colectivo: cola de bandas pendientes y reportes abiertos, con botones aprobar / suspender / ocultar tema.
- [ ] Anti-copyright liviano para el MVP: aprobación manual de bandas + reporte + política de "tres reportes → ocultar hasta revisión".

### 9.6 Accesibilidad y multiplataforma
- [ ] Perfil de banda adaptativo: en compu (≥600 px) dos columnas (info/redes a la izquierda, canciones a la derecha).
- [ ] Contraste suficiente y `Semantics`/tooltips en botones de íconos.
- [ ] Arreglar `tieneCamara` en web (usar la capacidad real del navegador a través de `DispositivoCapacidades`).

---

## 10. Plan de tareas por fases

> Cada fase termina con `dart format .` + `flutter analyze` + `flutter test` en verde. Asignar responsable y fecha en el tablero del equipo (columnas sugeridas: *Por hacer · En curso · En revisión · Hecho*).

### Fase 0 — Decisiones y preparación
- [ ] Confirmar las decisiones abiertas con Kiwi ([sección 11](#11-decisiones-pendientes-con-kiwi)).
- [ ] Crear el proyecto de **Supabase de prueba** y el de **producción** (separados).
- [ ] Definir la política de ramas y PRs ([sección 13](#13-guía-de-trabajo-del-equipo)).
- [ ] Revisar límites vigentes del plan gratuito de Supabase y estimar almacenamiento ([sección 12](#12-riesgos-y-costos)).

### Fase 1 — Supabase: esquema, seguridad y datos
- [ ] Ejecutar el SQL de la §7.2 en el proyecto de prueba y corregir errores.
- [ ] Activar RLS y crear las políticas de la §7.3.
- [ ] Endurecer: `status` de bandas solo por admin; `play_count`/`donations_collected` no editables desde la app.
- [ ] Crear buckets `audio`, `covers`, `stories` con sus políticas (§7.4).
- [ ] Activar Realtime en `donations`; habilitar `pg_cron` y programar las estadísticas diarias.
- [ ] Escribir `seed.sql` con datos de ejemplo (§7.7).
- [ ] **Probar las políticas** desde el SQL Editor simulando distintos usuarios (visitante, usuario, miembro, admin) y documentar los casos.
- [ ] Guardar todo en `supabase/migrations/` dentro del repo.

### Fase 2 — Capa de datos en Flutter
- [ ] Agregar `supabase_flutter` y `app_config.dart` con `--dart-define`.
- [ ] Crear modelos `Profile`, `Band`, `BandMember`, `Album` (y ajustar `Song`, `Donation`, `Playlist`) con `fromJson/toJson`.
- [ ] Definir **interfaces** de repositorios y las implementaciones `Fake*` (a partir de `MockData`).
- [ ] Implementar `Supabase*Repository` para canciones, bandas y playlists.
- [ ] Selección de implementación por `USE_MOCK` en `main.dart`.
- [ ] Mover todo acceso a `MockData` fuera de vistas y widgets (criterio C1).
- [ ] Adaptar los 10 tests a los fakes y agregar tests de repositorio.

### Fase 3 — Autenticación y sesión
- [ ] `AuthRepository` (registro, login, logout, recuperar contraseña).
- [ ] `SessionViewModel` + `SessionScope` (§8.3).
- [ ] Pantallas `LoginView` y `RegisterView`.
- [ ] Flujo "Crear mi banda" y estados `pending/approved/suspended`.
- [ ] Redirección de pantallas protegidas a login.
- [ ] Tests: sesión con y sin banda, `isMemberOf`, logout limpia el estado.

### Fase 4 — Perfiles separados y paneles
- [ ] **Perfil de usuario** (`ProfileView`): nombre, avatar, mis playlists, mis donaciones, mis bandas.
- [ ] **Perfil público de banda** (`BandPublicView`): portada, bio, redes, más escuchadas, historias, donar, reportar. Sin estadísticas.
- [ ] **Panel de banda** (`BandDashboardView`): estadísticas, donaciones, subir música, editar perfil, integrantes.
- [ ] Navegación por rol (§8.6) y selector de banda activa si el usuario tiene varias.
- [ ] Reemplazar `esDuenoDelPerfil` por `session.isMemberOf(band.id)`.
- [ ] Layout adaptativo del perfil para pantallas ≥600 px.

### Fase 5 — Funcionalidad real
- [ ] **Subida real**: `file_picker` + Storage + inserción en `songs`; cupo visible (X/20, Y/2) y errores del trigger mostrados al usuario.
- [ ] Subida en segundo plano con Workmanager + notificación al terminar.
- [ ] **Audio real** con `just_audio`; registrar `play_events` (con `seconds_listened`).
- [ ] `audio_session` para pausar/reanudar en llamadas (según la decisión de Kiwi) → criterio E3.
- [ ] Playlists reales desde cualquier pantalla (diálogo con "Nueva playlist").
- [ ] Buscador y filtro por género; "seguir banda".

### Fase 6 — Donaciones, estadísticas y moderación
- [ ] Donaciones: insertar en `donations` y escuchar Realtime como `Stream<Donation>` (muro/alerta).
- [ ] Estado real de "tope de gastos" (`app_config`) y su aviso en la UI.
- [ ] Estadísticas desde `band_daily_stats` + ranking (`band_top_listeners`) + gráfico; `Isolate`/`compute` para series largas.
- [ ] Reportes reales (`reports`) y **vista admin** (aprobar bandas, resolver reportes).
- [ ] Cámara: historias de 15 s (si Kiwi confirma) y arreglo de `tieneCamara` en web.

### Fase 7 — QA, publicación y defensa
- [ ] Revisión final de RLS (nadie ve estadísticas ajenas; nadie edita bandas ajenas).
- [ ] `flutter build web --release` y **deploy** (Vercel/Netlify/GitHub Pages) con las variables de entorno.
- [ ] Probar el PWA en **celu real** (instalar en pantalla de inicio) y en compu (criterio F2).
- [ ] Probar notificaciones, segundo plano y llamadas en un Android real (configurar Java 17 si hace falta).
- [ ] Informe final: arquitectura, decisiones, límites del MVP y **abono de mantenimiento** cotizado.
- [ ] **Guion de demo** (G1): usuario nuevo → crea banda → admin la aprueba → sube un tema → otro usuario lo escucha, lo agrega a una playlist y dona → la banda ve la alerta y las estadísticas. Tener el modo `USE_MOCK` como respaldo.

---

## 11. Decisiones pendientes con Kiwi

| # | Pregunta | Impacto | Supuesto actual |
|---|---|---|---|
| 1 | ¿Historias de 15 s con cámara, o la cámara solo para portadas? | Fase 6 (stories, permisos, Storage) | Historias habilitadas |
| 2 | ¿Ranking de oyentes que más minutos escucharon? | Estadísticas | Sí, se muestra |
| 3 | ¿Donaciones en muro público o aviso privado a la banda? | `donations.is_public`, UI | Público, con opción de ocultar |
| 4 | Al tocar la barra del reproductor: ¿pantalla completa o miniatura? | UX del reproductor | Pantalla completa |
| 5 | ¿La subida sigue en segundo plano con la app cerrada? | Workmanager | Sí |
| 6 | Tras una llamada: ¿reanuda solo o manual? | E3 / `audio_session` | **Sin definir** (hoy no reanuda) |
| 7 | ¿Alguna sección que deba verse distinta en compu? | Layout adaptativo | Perfil de banda en dos columnas |
| 8 | ¿Quién modera y con qué turnos? ¿Cuántos reportes ocultan un contenido? | Fase 6 | Aprobación manual + 3 reportes |
| 9 | ¿Una persona puede estar en varias bandas? | `band_members` | Sí |
| 10 | Medio de pago real para donaciones | Costos y legales | MercadoPago, post-MVP |

---

## 12. Riesgos y costos

| Riesgo | Mitigación |
|---|---|
| **Almacenamiento de audio:** MP3 192 kbps ≈ 24 KB/s ≈ **~1,4 MB por minuto**; un tema de 4 min ≈ 5,8 MB y 20 temas ≈ **~115 MB por banda**. | Verificar la cuota del plan gratuito vigente y calcular cuántas bandas entran; mantener el límite y los 192 kbps; avisar al Colectivo cuándo hará falta pasar a un plan pago. |
| **Factura sorpresa** por picos de tráfico. | Tope de gastos (spend cap) del proveedor + aviso "alta demanda" real en la app. |
| **Música de terceros / copyright.** | Banda `pending` + aprobación humana + reportes + ocultar canciones. |
| **Claves expuestas.** | Solo `anon key` en el cliente, RLS en todas las tablas, `.env`/`--dart-define`, nada en Git. |
| **RLS mal escrita** (filtra datos). | Probar cada política con distintos roles (Fase 1 y 7). |
| **Sin internet en la defensa.** | Modo `USE_MOCK` + video de respaldo de la demo. |
| **Cambios de alcance.** | Todo lo no pedido por Kiwi va a "versión 2" (offline, tiendas, tiempo real de estadísticas). |
| **Plan de pruebas en Android** bloqueado por entorno (JDK 17). | Resolver temprano `JAVA_HOME` y probar en un equipo. |

**Fuera del alcance del MVP (v2):** modo offline, publicación en tiendas, estadísticas en tiempo real, pagos reales, recomendaciones algorítmicas.

---

## 13. Guía de trabajo del equipo

### 13.1 Correr el proyecto
```bash
flutter pub get
flutter run -d chrome                         # web
flutter run -d chrome --dart-define=USE_MOCK=true   # modo demo sin internet (cuando exista)
dart format .
flutter analyze
flutter test
```
Para Android hace falta **JDK 17+** configurado (`JAVA_HOME`).

### 13.2 Git
- Rama de integración: `fase2-mvp`. Trabajo en ramas `feat/…`, `fix/…`, `refactor/…`.
- PRs chicos y con una sola responsabilidad; **un compañero revisa** antes de mergear.
- Commits descriptivos (`feat: panel de banda`, `refactor: repositorios con interfaz`). Los commits de refactor sirven de evidencia para el criterio C3.
- `.idea/`, `build/`, claves y `.env` **nunca** al repo.

### 13.3 Definición de "hecho"
1. Cumple las reglas de la §3.2.
2. `dart format .`, `flutter analyze` y `flutter test` en verde.
3. Tiene test (o justificación de por qué no).
4. Probado a mano en web y, si toca cámara/segundo plano/notificaciones, en un celu.
5. Este documento actualizado si cambia una decisión.

### 13.4 Entrega (zip o repo)
Sin `build/`, `.idea/`, `.dart_tool/` ni claves. Con `README.md` actualizado, este plan, `supabase/migrations/` y `seed.sql`.

---

## 14. Anexo: reglas y prompts para la IA (Antigravity)

### 14.1 Contexto para pegar al inicio de cada sesión
```
Proyecto StreamTunes (Flutter, PWA). Reglas obligatorias:
1) Capas: models → repositories → services → view_models → views/widgets. Las vistas no leen datos directo.
2) Estado solo con ChangeNotifier + ListenableBuilder + InheritedNotifier globales
   (ReproductorScope, LibraryScope, SessionScope). Prohibido prop-drilling y paquetes
   de estado externos.
3) Prohibido kIsWeb / Platform / defaultTargetPlatform en vistas y view models;
   va en DispositivoCapacidades o servicios.
4) async/await, Isolate.run (nativo) / compute (web) encapsulado, Streams con cancel() en dispose().
5) Tras cada cambio: dart format ., flutter analyze sin avisos, flutter test en verde.
No agregues dependencias sin avisar. Lee el archivo antes de modificarlo.
```

### 14.2 Prompts por fase (ejemplos)

**Fase 2 — Repositorios con interfaz**
> "Crea la interfaz abstracta `SongRepository` en `lib/repositories/interfaces/` con `getLatestSongs()`, `getSongsByBand(bandId)`, `addSong(...)` y `watch...` si corresponde. Implementá `FakeSongRepository` basado en `MockData` y `SupabaseSongRepository` usando `supabase_flutter`. Elegí la implementación en `main.dart` según `bool.fromEnvironment('USE_MOCK')`. Las vistas y widgets no deben importar `MockData`."

**Fase 3 — Sesión**
> "Crea `SessionViewModel` (ChangeNotifier) con `profile`, `myBands`, `activeBand`, `isLoggedIn`, `isMemberOf(bandId)`, `isOwnerOf(bandId)` y `isAdmin`, y un `SessionScope` (InheritedNotifier) igual que `ReproductorScope`. Reemplazá `MockData.artistaLogueadoId` y `esDuenoDelPerfil` por `SessionScope.of(context).isMemberOf(band.id)`. Agregá tests con repositorios fake."

**Fase 4 — Panel de banda**
> "Crea `BandDashboardView` y su ViewModel: muestra reproducciones de ayer, donaciones recientes, cupo de subida (X/20 temas, Y/2 álbumes) y accesos a subir música y editar perfil. Solo accesible si `session.isMemberOf(activeBand.id)`; si no, redirigir. Sin lógica de plataforma en la vista."

**Fase 5 — Audio real y llamadas**
> "Reemplazá el `Timer` simulado de `ReproductorViewModel` por `just_audio` encapsulado en un `AudioService`. Usá `audio_session` para pausar ante interrupciones (llamadas) y reanudar según una constante de política `reanudarTrasLlamada`. Mantené la API pública del ViewModel (`play`, `pause`, `togglePlay`, `cambiarTema`, `currentSong`, `isPlaying`) para no romper los tests."

**Fase 6 — Donaciones en vivo**
> "Reemplazá el `Timer` simulado de `DonacionesService` por un canal de Supabase Realtime sobre la tabla `donations` filtrado por `band_id`, expuesto como `Stream<Donation>`. Cancelá la suscripción y el canal en `dispose()`. Mantené el test del Bloque 5 usando un fake que emita por `StreamController`."

### 14.3 Cómo trabajar con la IA sin romper cosas
- Un prompt = un objetivo chico. Revisar el *diff* antes de aceptar.
- Si la IA toca archivos que no pediste, rechazar ese cambio.
- Correr `flutter analyze` y `flutter test` **antes de cada commit**, no solo al final.
- Pedirle que explique cualquier cambio de arquitectura: tienen que poder defenderlo en la demo.

---

*Última actualización: 9/11/2026. Mantener este archivo vivo: cada decisión nueva o cambio de alcance se registra acá mediante PR.*
