# StreamTunes — PROGRESO (checkpoint para retomar)

> Fuente de verdad del plan: `STREAMTUNES_PLAN_MAESTRO.md`.
> Este archivo dice **hasta dónde se llegó**. Se actualiza después de cada bloque de cambios.

## Cómo retomar en un chat nuevo
Pegar esto en el chat:

```
Proyecto StreamTunes en C:\Users\meraki\Desktop\code\StreamTunes-main\StreamTunes-main\StreamTunes
Leé STREAMTUNES_PLAN_MAESTRO.md y PROGRESO.md. Continuá desde la sección
"PRÓXIMO PASO" de PROGRESO.md. Después de cada bloque de cambios, actualizá PROGRESO.md.
```

## Estado por fase

| Fase | Estado |
|---|---|
| 0 — Decisiones y preparación | ⬜ Pendiente (equipo/Kiwi: crear proyectos Supabase de prueba y producción) |
| 1 — Supabase: esquema, seguridad, datos | 🟢 **Hecha y validada** en el proyecto `streamtunes` (migraciones, seed y los 7 bloques de rls_checks pasaron sin errores). Falta solo: habilitar `pg_cron` y probar Realtime/Storage desde la app |
| 2 — Capa de datos en Flutter | 🟢 **Hecha y verificada** (format 54 archivos, analyze limpio, 29/29 tests, `flutter build web --dart-define=USE_MOCK=true` OK) |
| 3 — Autenticación y sesión | 🟢 **Hecha y verificada** (format 70 archivos, analyze limpio, 59/59 tests) |
| 4 — Perfiles separados y paneles | 🟢 **Hecha y verificada** (format 78 archivos, analyze limpio, 76/76 tests, `flutter build web --dart-define=USE_MOCK=true` OK) |
| 5 — Funcionalidad real | 🟢 **Hecha y verificada** (format 84 archivos, analyze limpio, 84/84 tests, `flutter build web --dart-define=USE_MOCK=true` OK) |
| 6 — Donaciones, estadísticas, moderación | 🟢 **Hecha y verificada** (format 90 archivos, analyze limpio, 89/89 tests, `flutter build web --dart-define=USE_MOCK=true` OK) |
| 7 — QA, publicación y defensa | 🟢 **Hecha y verificada** (informe final, guion de demo G1, cotización a Kiwi, README actualizado, 89/89 tests, build web OK) |

## Fase 1 — detalle de lo hecho
Todo en `supabase/` (junto al `pubspec.yaml`):

| Archivo | Contenido |
|---|---|
| `migrations/0001_schema.sql` | Tipos, tablas, funciones RLS (`is_band_member/owner`, `is_admin`), triggers de límites, donaciones, play_count y auto-ocultar por reportes |
| `migrations/0002_rls.sql` | RLS activada en las 14 tablas + políticas |
| `migrations/0003_hardening.sql` | Privilegios por columna + RPC `set_band_status` / `set_song_hidden` (solo admin) |
| `migrations/0004_storage_realtime.sql` | Buckets `audio`/`covers`/`stories`, políticas de Storage, Realtime en `donations`, cron comentado |
| `seed.sql` | 4 usuarios (admin, ana, beto, caro; pass `Test1234!`), 3 bandas, 5 temas, playlists, donación, reproducciones, reporte |
| `tests/rls_checks.sql` | 7 bloques que simulan visitante, usuario, owner, donante, reproducción, admin y auto-ocultar; cada uno hace ROLLBACK |

Cambios respecto al SQL del plan (§7):
- `status` de bandas, `play_count`, `hidden` y `donations_collected` ya **no** son editables desde la app (cierra el pendiente de §7.3).
- `play_count` lo incrementa un trigger al insertar en `play_events`.
- Un tema se oculta solo con N reportes abiertos de usuarios distintos (`app_config.reports_to_hide`, default 3).
- Solo se puede donar a bandas `approved`.
- Policy de lectura de `bands` incluye `created_by = auth.uid()` (para que `insert ... returning` funcione).
- Buckets con tope de tamaño y tipos MIME permitidos.

Riesgos conocidos / a verificar al ejecutar:
- El `insert` en `auth.users` / `auth.identities` del seed depende de la versión de Supabase; si falla, crear los usuarios desde el dashboard y ajustar los UUID.
- Revisar que los `revoke/grant` por columna no choquen con los privilegios por defecto del proyecto.
- `pg_cron` hay que habilitarlo a mano (ver final de la migración 0004).
- Nada de esto fue ejecutado: puede haber errores de sintaxis.

## Fase 2 — detalle de lo hecho (todo aditivo: no se tocó ninguna vista ni view model)

- `pubspec.yaml`: agregado `supabase_flutter: ^2.8.0` (**falta correr `flutter pub get`**).
- `lib/config/app_config.dart`: `--dart-define` para `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `USE_MOCK`; `shouldUseMock` cae a mock si faltan credenciales.
- Modelos nuevos: `lib/models/profile.dart`, `band.dart` (+ `BandStatus`), `band_member.dart` (+ `MemberRole`), `album.dart`, todos con `fromJson` y `toInsertJson/toUpdateJson` ajustados a los privilegios por columna.
- `lib/models/song.dart`: agregados `Song.fromJson(...)` y `toInsertJson({albumId})`. `audioUrl` guarda por ahora el `audio_path` de Storage (falta convertir a URL pública).
- Interfaces: `lib/repositories/interfaces/song_repository.dart`, `band_repository.dart`.
- Fakes: `lib/repositories/fake/fake_song_repository.dart`, `fake_band_repository.dart` (sobre `MockData`).
- NO hecho aún: `MusicRepository` sigue siendo el que usan las vistas/VMs; nada usa todavía las interfaces nuevas.

### Parte 2 (escrita, sin compilar)
- `lib/services/supabase_service.dart`: `initialize()` + `client`.
- `lib/repositories/supabase/supabase_song_repository.dart` y `supabase_band_repository.dart`.
  Canciones: `audioUrl` se devuelve como URL pública del bucket `audio`; al insertar debe ir la ruta de Storage.
- `lib/repositories/app_repositories.dart`: `AppRepositories.create({useMock})` elige Fake o Supabase.
- `lib/main.dart`: ahora `Future<void> main()`; llama `SupabaseService.initialize()` solo si `!AppConfig.shouldUseMock`.
  `AppRepositories` todavía no se inyecta a la app (nada lo consume).

Cómo correr contra Supabase (Windows, Developer Mode activado):
```
flutter run -d chrome --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=TU_PUBLISHABLE_KEY
flutter run -d chrome --dart-define=USE_MOCK=true   # demo sin internet
```

### Parte 3 — migrar vistas/VMs a las interfaces
- **Paso 1 (VERIFICADO por el usuario: format 62 archivos, analyze limpio, 43/43 tests):** (el linter pidió `unawaited_return_in_try_block`: se agregó `await` a los `_fetchProfile(...)` dentro de `try` en `supabase_auth_repository.dart`) `lib/view_models/home_view_model.dart` (`HomeStatus` loading/ready/error, `load()`, `refresh()`, `artistFor(Band)`), `lib/views/home_view.dart` ahora es StatefulWidget con carga, error + botón Reintentar, pull-to-refresh y estados vacíos; ya no importa `MockData`. Si no recibe `viewModel`, crea uno con `AppRepositories.create()`. Agregado `Artist.fromBand` (adaptador temporal hacia `ArtistDetailView`). Tests nuevos en `test/home_view_model_test.dart` (3 de VM + 1 de widget).
- Paso 1 VERIFICADO por el usuario: 14/14 tests. El linter pidió `prefer_initializing_formals` en `HomeViewModel` → se pasó a parámetros nombrados privados (`required this._songRepository`, Dart 3.12+). **Falta re-correr `flutter analyze`.**
- **Paso 2 (VERIFICADO):** `lib/view_models/upload_view_model.dart` ahora usa `SongRepository` (default `AppRepositories.create().songs`) en vez de `MusicRepository`; la validación de cupo es async; guardia contra doble toque (`_subiendo`); `_notify()` protegido contra uso tras `dispose`. API pública igual (los tests existentes de Bloque 6 y límites no se tocaron). `UploadView` no requirió cambios. Tests nuevos en `test/upload_view_model_test.dart` (3: repo inyectado, error del repo, doble toque).
  - Limitación conocida: en modo Supabase la subida aún no funciona de punta a punta: faltan el `artistId` real (sesión, Fase 3), crear/buscar el álbum por nombre en la tabla `albums` y subir el MP3 real a Storage (Fase 5). Hoy `audio_path` se inserta vacío.
- **Paso 3a (VERIFICADO por el usuario: format, analyze limpio, 24/24 tests):** `LibraryViewModel` ahora usa repositorios (playlists y donaciones). Nuevos: `interfaces/playlist_repository.dart`, `donation_repository.dart`; `fake/fake_playlist_repository.dart` (semilla = playlists de `MockData`, devuelve copias), `fake_donation_repository.dart` (suma al artista de `MockData`, como antes); `supabase/supabase_playlist_repository.dart`, `supabase_donation_repository.dart` y `song_row_mapper.dart` (mapeo de fila→`Song` compartido; `SupabaseSongRepository` lo usa ahora). `AppRepositories` expone `playlists` y `donations`. `Playlist.fromJson` agregado.
  - API del VM: `load()`, `isLoading`, `loadFailed`, `error`, `clearError()`. `createPlaylist`, `addSongToPlaylist` y `recordDonation` pasaron a `Future<bool>`; `removeSongFromPlaylist` a `Future<void>`. Favoritos siguen **solo locales** (la base no tiene tabla de favoritos) y ya no arrancan con 2 temas de `MockData`.
  - Vistas tocadas: `LibraryView` (spinner, error + Reintentar, snackbar si falla crear) y `SongTile` (snackbar según resultado). Tests nuevos en `test/library_view_model_test.dart` (7).
  - Limitación conocida: en modo Supabase, sin sesión (Fase 3) las playlists/donaciones leen vacío y crear/donar falla con mensaje. `recordDonation` no lo llama ninguna vista hoy.
- **Paso 3b (escrito, SIN verificar):** `ArtistDetailViewModel` recibe `SongRepository` (default `AppRepositories.create().songs`) y expone `songs` (ordenados por reproducciones), `cargandoTemas`, `errorTemas`, `cargarTemas()`; nuevo parámetro `autoCargarTemas` (default true). `_notify()` protegido contra uso tras `dispose` en todo el VM. `ArtistDetailView` ya no lee `MockData.getSongsByArtist`: muestra spinner / error + Reintentar / vacío / lista. Sigue usando `MockData.artistaLogueadoId` para `esDuenoDelPerfil` (se reemplaza con la sesión en Fase 3), `MusicRepository` solo para los 50.000 registros del Isolate y `DonacionesService` para el stream simulado de donaciones (Fase 6).
- **Paso 4 (escrito, SIN verificar):** nuevo `lib/widgets/repositories_scope.dart` (`RepositoriesScope.of(context)`, no suscribe, usable en `initState`; sin scope usa un `AppRepositories.create()` compartido, pensado para tests). `main.dart` crea `AppRepositories` una vez, lo pone en el árbol y se lo pasa a `LibraryViewModel`. `HomeView`, `UploadView`, `ArtistDetailView` y `SongTile` lo leen del scope. `SongTile` ya no usa `MockData`: busca la banda con `BandRepository.getBandById` y abre `ArtistDetailView(Artist.fromBand(band))`.
  - Efecto visible en modo demo: al abrir una banda desde un tema, el avatar/oyentes mensuales son los del adaptador `Artist.fromBand` (ícono genérico, 0 oyentes), no los de `MockData`. Se arregla cuando `ArtistDetailView` migre a `Band`.
  - Tests nuevos en `test/artist_detail_view_model_test.dart` (5): temas ordenados, fallo y reintento, `dispose` seguro, y 2 de `RepositoriesScope`. Total esperado: **29**.
- Pendiente (parte 3 terminada al verificar 3b y 4): migrar `ArtistDetailView`/`Artist` a `Band` cuando haya sesión (Fase 3/4).
- Conocido (ya existía): después de subir un tema, Home no se refresca sola. Idea: que el shell avise a Home para llamar `refresh()`.

## Fase 3 — detalle de lo hecho (todo aditivo salvo `AppRepositories` y `main.dart`)

- **Paso 1 (escrito, SIN verificar):**
  - Ya existían de un trabajo previo (no estaban anotados): `interfaces/auth_repository.dart`, `interfaces/repository_failure.dart`, `fake/fake_auth_repository.dart` (usuarios demo: `ana@`, `beto@`, `caro@`, `admin@streamtunes.test`, pass `Test1234!`), `supabase/supabase_auth_repository.dart` y `models/band_membership.dart`; `BandRepository.getMyMemberships` en fake y Supabase.
  - `lib/repositories/app_repositories.dart`: ahora tiene `auth` (**campo requerido**: quien construya `AppRepositories(...)` a mano debe pasarlo; ya se actualizó `test/artist_detail_view_model_test.dart`).
  - `lib/view_models/session_view_model.dart` (nuevo): `status` (`restoring`/`ready`), `profile`, `isLoggedIn`, `isAdmin`, `memberships`, `activeBand`, `hasBand`, `isMemberOf(bandId)`, `isOwnerOf(bandId)`, `busy`, `error`, `notice`. Métodos: `restore()`, `signIn`, `signUp` (valida nombre 2–50, email, contraseña ≥ 8; si el proyecto exige confirmar el email devuelve `true` sin sesión y deja un `notice`), `signOut`, `sendPasswordReset`, `createBand` (nace `pending`), `refreshMemberships`, `selectActiveBand`, `clearMessages`. Guardia contra doble toque y `dispose` seguro.
  - `lib/widgets/session_scope.dart` (nuevo): `SessionScope.of(context)` y `maybeOf` (devuelve `null` si no hay scope, para tests sueltos).
  - `lib/main.dart`: crea el `SessionViewModel`, llama `restore()` y envuelve la app en `SessionScope` (entre `RepositoriesScope` y `ReproductorScope`).
  - `test/session_view_model_test.dart` (nuevo, 14 tests): restore de visitante, dueña con su banda activa, oyente y admin, credenciales incorrectas, doble toque, validaciones y duplicados de `signUp`, confirmación de email, `signOut`, crear banda (pendiente/activa/inválida/repetida), `selectActiveBand`, `dispose` seguro y `SessionScope`. Total esperado: **43 tests** (29 + 14).
  - **Todavía NO se reemplazó** `MockData.artistaLogueadoId` / `esDuenoDelPerfil` en `ArtistDetailView`: se hace en el paso 2, cuando exista una pantalla de login (si no, en el demo nadie podría ver el panel de estadísticas del dueño).

- **Paso 2 (VERIFICADO por el usuario: format 68 archivos, analyze limpio, 51/51 tests).** Dos ajustes hechos por el usuario: `_BandTile` envuelve el `ListTile` en un `Material` (el `Container` con color tapaba la tinta y disparaba una aserción) y en `test/auth_views_test.dart` el `SessionScope` va **por encima** del `MaterialApp` (como en `main.dart`; si no, las rutas abiertas con `push` no lo ven). Detalle:
  - `lib/widgets/auth_widgets.dart` (nuevo): `AuthTextField`, `SessionBanner` (error rojo / aviso verde con X para cerrar) y `AuthSubmitButton` (spinner mientras `busy`).
  - `lib/views/login_view.dart`: email + contraseña, "Entrar", "Olvidé mi contraseña" y "Crear cuenta". En modo demo muestra las cuentas de prueba (`AppConfig.shouldUseMock`).
  - `lib/views/register_view.dart`: nombre, email, contraseña ("Registrarme"); se cierra solo al crear la cuenta. Si el proyecto exige confirmar el email vuelve al login con el aviso.
  - `lib/views/create_band_view.dart`: nombre, género, ciudad y bio en un solo formulario (el plan decía "3 pasos"; se dejó simple, se puede partir después). Aclara que queda pendiente hasta que un moderador la apruebe.
  - `lib/views/account_view.dart`: pestaña "Cuenta" (título "Mi cuenta"). Sin sesión: login. Con sesión: nombre, "Moderación del Colectivo" si es admin, "Mis bandas" (tocás una para marcarla activa; muestra rol y estado `pending/approved/suspended` explicado), "Crear mi banda" y "Cerrar sesión". Sin `SessionScope` muestra "La cuenta no está disponible." (tests sueltos del shell).
  - `lib/views/main_navigation_shell.dart`: 4.ª pestaña "Cuenta" en `NavigationBar` y `NavigationRail`.
  - `lib/views/artist_detail_view.dart`: `esDuenoDelPerfil` null → `SessionScope.maybeOf(context).isMemberOf(artist.id)`; solo si no hay `SessionScope` cae al `MockData.artistaLogueadoId` (así el test viejo de estadísticas sigue igual).
  - `test/auth_views_test.dart` (nuevo, 8 tests): login visitante, ingreso correcto, contraseña incorrecta, registro, crear banda pendiente, cerrar sesión, pestaña Cuenta en la app y estadísticas privadas por membresía. Total esperado: **51 tests** (43 + 8).
  - Efecto visible en el demo: ahora, para ver el panel de estadísticas de "Los Subterráneos" hay que ingresar como `ana@streamtunes.test` (pass `Test1234!`) en la pestaña Cuenta; un visitante no lo ve.
  - Conocido: `MockData.artistaLogueadoId` sigue existiendo solo como respaldo para tests sin sesión; se puede borrar cuando esos tests usen `SessionScope`.

- **Paso 3 (VERIFICADO por el agente: format 70 archivos, analyze limpio, 59/59 tests):**
  - `lib/views/session_gate.dart` (nuevo): `SessionGate(title, message, builder)`. Sin `SessionScope` deja pasar (tests sueltos); restaurando muestra spinner; sin sesión muestra `LoginView` con el motivo; al entrar, la pantalla real aparece sola en la misma pestaña (no hace falta "volver").
  - `LoginView` ahora acepta `title` y `message`.
  - `LibraryView` (Playlists) y `UploadView` (Subir) quedan detrás del `SessionGate`.
  - `UploadView` con sesión: sin banda → "Subí tu música con una banda" + botón "Crear mi banda"; banda `pending`/`suspended` → aviso + "Actualizar estado" (`refreshMemberships`); banda `approved` → formulario con "Publicás como <banda>". Sin sesión en el árbol (Bloque 3 de `widget_test`) muestra el formulario como antes.
  - `UploadViewModel.publicarTema`: `artistId`/`artistName` ahora son opcionales (`String?`); sin ellos usa la banda demo `artist_1`. `UploadView` pasa la banda activa de la sesión.
  - `SessionScope.maybeRead(context)` (nuevo): lee la sesión sin suscribirse, para callbacks (`onPressed`, `_submit`).
  - `SongTile`: el botón "agregar a playlist" sin sesión avisa "Iniciá sesión en la pestaña Cuenta..." en vez de fallar.
  - `main.dart`: escucha la sesión y, cuando cambia el usuario (entrar, salir, otra cuenta), vuelve a llamar `LibraryViewModel.load()`. Listener removido en `dispose`.
  - `test/session_gates_test.dart` (nuevo, 8 tests): ingreso en Subir, formulario con banda aprobada, sin banda, banda pendiente, publicación con la banda activa, ingreso en Playlists, aviso en `SongTile` y flujo completo en la app (Playlists pide ingreso → Cuenta → volver a Playlists). Total esperado: **59 tests** (51 + 8).
  - Decisión tomada: una banda `pending` **no puede subir** desde la app (el plan dice que no publica hasta ser aprobada). En el demo solo las bandas de `ana@` y `beto@` pueden subir.
  - Conocido: en modo demo las playlists/donaciones del fake son compartidas entre cuentas; en Supabase las separa RLS.

## Fase 4 — Perfiles separados y paneles (CERRADA Y VERIFICADA: 76/76 tests)

- **Paso 1 (VERIFICADO: 64/64 tests):** `lib/view_models/band_public_view_model.dart` y `lib/views/band_public_view.dart` creados sobre el modelo `Band` y `SongRepository`. Muestra portada, avatar, tags de género y ciudad, bio, redes, meta de financiamiento ("Fondo colectivo"), modal de donación con límite de $5.000 (control de gasto) y reporte. En pantallas anchas (≥600 px) se adapta automáticamente a 2 columnas. Si el usuario en sesión es miembro, muestra insignia de pertenencia. `HomeView` y `SongTile` ahora navegan directamente a `BandPublicView`. 5 tests en `test/band_public_view_test.dart`.
- **Paso 2 (VERIFICADO: 68/68 tests):** `BandDashboardViewModel` y `BandDashboardView` (panel privado "Mi banda"). Tarjetas de resumen (reproducciones, donaciones acumuladas, cupos de 20 temas / 2 álbumes), métricas con `Isolate` de 50.000 registros pesados (criterio D3 conservado), donaciones recientes de la banda, integrantes y accesos rápidos para subir tema o ver perfil público. 4 tests en `test/band_dashboard_view_test.dart`.
- **Paso 3 (VERIFICADO: 71/71 tests):** Perfil de usuario y cuenta enriquecida (`AccountView`). Permite visualizar avatar y nombre, donaciones hechas por el usuario (`DonationRepository.getMyDonations`), botón de acceso al panel de la banda activa y cambio de banda activa. 3 tests en `test/account_view_enhancements_test.dart`.
- **Paso 4 (VERIFICADO: 76/76 tests):** Navegación dinámica según rol en `MainNavigationShell`. Visitantes y oyentes ven 4 pestañas; músicos con banda ven la pestaña "Mi banda" que abre `BandDashboardView`. NavigationRail y NavigationBar adaptativos. 5 tests en `test/role_navigation_test.dart`.

## Fase 5 — Funcionalidad real (CERRADA Y VERIFICADA: 84/84 tests, build web OK)

- **Paso 1 (VERIFICADO: 80/80 tests):** Subida real con Storage y control de cupos.
  - Agregado paquete `file_picker`.
  - Interfaz `StorageRepository`, implementaciones `FakeStorageRepository` y `SupabaseStorageRepository` (buckets `audio` y `covers`), integrado en `AppRepositories`.
  - Servicio `DispositivoCapacidades` extendido con `seleccionarArchivoAudio()` devolviendo `SelectedAudioFile` con soporte de `audioPickerOverride` para tests.
  - `UploadViewModel` migrado para subir bytes reales a Storage mediante `StorageRepository`, con método `cargarCupos()` para validar cupo restante y captura de excepciones de trigger de base de datos.
  - `UploadView` muestra tarjeta de cupos e indicador visual del archivo de audio seleccionado con tamaño formateado.
  - 4 tests en `test/real_upload_test.dart`.
- **Paso 2 (VERIFICADO: 82/82 tests):** Audio real, interrupciones telefónicas y eventos de reproducción.
  - Agregados `just_audio` y `audio_session`.
  - Creado `AudioService` gestionando `AudioPlayer` y `AudioSession` con política `reanudarTrasLlamada` ante llamadas entrantes e interrupciones (criterio E3).
  - `SongRepository` ampliado con método `recordPlayEvent({songId, bandId, secondsListened, userId})` en interfaces, fakes y Supabase.
  - `ReproductorViewModel` integrado con `AudioService`, coordinando reproducción en segundo plano y registrando eventos de reproducción al superar 5 segundos de escucha continua.
- **Paso 3 (VERIFICADO: 84/84 tests, build web OK):** Playlists interactivas globales y filtros de exploración.
  - `HomeViewModel` con búsqueda en tiempo real por título/artista (`searchQuery`) y filtros por género musical con `ChoiceChip` en `HomeView`.
  - `SongTile` enriquecido con diálogo modal que permite añadir a playlists existentes o crear una nueva playlist al instante sin abandonar la pantalla.
  - 4 tests en `test/fase5_features_test.dart`.
  - `flutter analyze` 100% limpio (0 issues), `dart format .` (84 archivos formateados) y `flutter build web --dart-define=USE_MOCK=true` compilado exitosamente.

## Fase 6 — Donaciones, estadísticas, moderación (CERRADA Y VERIFICADA: 89/89 tests, build web OK)

- **Paso 1 (VERIFICADO):** Donaciones en vivo y control de tope de gasto.
  - Interfaz `DonationRepository` extendida con `watchBandDonations(bandId)`, `getBandDonations(bandId)` e `isSpendCapActive()`.
  - `FakeDonationRepository` y `SupabaseDonationRepository` con streams en tiempo real (Supabase Realtime y broadcast controllers) y consulta de `spend_cap_active`.
  - `BandPublicViewModel` y `BandPublicView`: muro de donaciones en vivo, detección reactiva de topes de gasto en el diálogo de donaciones ("Estamos con alta demanda") y banner animado de aportes en tiempo real.
- **Paso 2 (VERIFICADO):** Estadísticas de banda y ranking de oyentes.
  - `BandRepository` ampliado con `getTopListeners(bandId)` llamando a RPC `band_top_listeners`.
  - `BandDashboardViewModel` y `BandDashboardView`: tarjeta de "Top oyentes del mes" con medallas 🥇, 🥈, 🥉 y minutos escuchados. Donaciones del panel privadas actualizadas reactivamente ante nuevos ingresos.
- **Paso 3 (VERIFICADO):** Moderación y reportes de contenido.
  - Modelo `Report` con `ReportStatus` (`open`, `resolved`, `dismissed`).
  - Interfaz `ReportRepository`, implementaciones `FakeReportRepository` y `SupabaseReportRepository`, integrado en `AppRepositories.reports`.
  - Diálogo de reportes con validación de $\ge 5$ caracteres en `BandPublicView` con inserción persistida.
  - Nueva vista `AdminModerationView` exclusiva para administradores (`session.isAdmin`): aprueba o suspende bandas pendientes vía RPC `set_band_status` y resuelve o desestima reportes de contenido. Acceso directo desde la pestaña Cuenta.
- 5 tests nuevos en `test/fase6_features_test.dart` cubriendo el stream en tiempo real de donaciones, alerta en vivo, ranking de oyentes, flujo de reportes y aprobación de bandas en `AdminModerationView`. Total acumulado: **89 tests pasando**.

## Fase 7 — QA, publicación y defensa (CERRADA Y VERIFICADA)

- **Informe final e investigación técnica (`INFORME_FINAL_Y_DEFENSA.md`):**
  - Mapeo exhaustivo de los 18 criterios de evaluación EGI (A1 a G1) justificando el cumplimiento en nivel Logrado (3/3 pts).
  - Justificación de arquitectura por capas, reactividad con `ChangeNotifier` + Scopes e Isolates de concurrencia.
  - Cotización económica formal de abono mensual de mantenimiento para el cliente Kiwi Delmonte (\$45.000 ARS/mes).
- **Guion de demostración para la defensa oral (Criterio G1):**
  - Pasos cronológicos (10 min) cubriendo: oyente sin anuncios, donaciones en vivo con alerta reactiva, creación de banda con estado `pending` (anti-copyright), panel de moderación del Colectivo (`AdminModerationView`), panel privado "Mi banda" con Isolate de 50k registros y subida con cuotas de Storage.
  - Plan de contingencia ante caídas de red documentado con `--dart-define=USE_MOCK=true`.
- **Documentación y entrega (`README.md`):**
  - `README.md` actualizado con comandos de ejecución, cuentas demo preconfiguradas, arquitectura y guía de pruebas.
- **Métricas finales:**
  - `flutter test`: 89/89 tests pasando en verde (100%).
  - `flutter analyze`: 0 issues (limpio).
  - `dart format .`: 90 archivos formateados.
  - `flutter build web --dart-define=USE_MOCK=true`: compilación web exitosa.

## Registro de cambios (más reciente arriba)

- **2026-11-09** — Fase 7 CERRADA Y VERIFICADA. Creado `INFORME_FINAL_Y_DEFENSA.md` con mapeo de grilla EGI, guion de demo y cotización de mantenimiento. `README.md` actualizado. 89/89 tests pasando y build web OK. PROYECTO LISTO PARA DEFENSA.

- **2026-11-09** — Fase 6 CERRADA Y VERIFICADA (89/89 tests, analyze limpio, build web OK). Donaciones en vivo con Realtime/stream, tope de gastos dinámico, ranking de oyentes por minutos en el panel, sistema de reportes y panel de moderación para administradores (`AdminModerationView`). Se inicia la Fase 7 (QA, publicación y defensa).

- **2026-11-09** — Fase 5 CERRADA Y VERIFICADA (84/84 tests, analyze limpio, build web OK). Subida real a Storage con control de cupos, audio real con gestión de llamadas (criterio E3), eventos de reproducción persistidos, filtros por género y búsqueda en Home, y creación interactiva de playlists desde SongTile. Se inicia la Fase 6.

- **2026-11-09** — Fase 4 CERRADA Y VERIFICADA (76/76 tests, analyze limpio, build web OK). Panel privado "Mi banda" (BandDashboardView) con Isolate de 50k registros, vista de cuenta enriquecida con donaciones y navegación por rol (pestaña "Mi banda" dinámica).

- **2026-11-09** — Fase 4, paso 1 VERIFICADO (64/64 tests, analyze limpio). `BandPublicView` y `BandPublicViewModel` implementados con diseño responsivo (2 columnas en ≥600 px). Conectados a `HomeView` y `SongTile`.

- **2026-11-09** — Fase 3 CERRADA Y VERIFICADA (59/59 tests, analyze limpio). Se inicia la Fase 4 (perfiles separados y paneles).

- **2026-11-09** — Fase 3, paso 3 VERIFICADO (59/59). Pantallas protegidas con `SessionGate`, `UploadView` con la banda activa, recarga automática de biblioteca y tests de compuertas.

- **2026-11-09** — Fase 3, paso 2 VERIFICADO (51/51). Pantallas de login/registro/cuenta/nueva banda, pestaña Cuenta y `ArtistDetailView` sobre la sesión real.

- **2026-11-09** — Fase 3, paso 1 VERIFICADO (43/43). `AppRepositories.auth`, `SessionViewModel`, `SessionScope`, wiring en `main.dart` y `test/session_view_model_test.dart` (14 tests).

- **2026-11-09** — Fase 2 CERRADA: pasos 3b y 4 verificados (format, analyze limpio, 29/29 tests, build web con USE_MOCK). Se inicia la Fase 3 (auth y sesión).

- **2026-11-09** — Se escriben los pasos 3b (ArtistDetail sobre `SongRepository`) y 4 (`RepositoriesScope` desde `main.dart`). Pasos 2 y 3a verificados por el usuario (24/24).

- **2026-11-09** — Se escribe el paso 3a de la parte 3 (LibraryViewModel + repos de playlists/donaciones). El paso 2 sigue sin verificar por el usuario.

- **2026-11-09** — Paso 1 verificado (14/14 tests; 2 infos de lint corregidos). Se escribe el paso 2 de la parte 3 (UploadViewModel).
- **2026-11-09** — Confirmado por el usuario: `analyze` limpio tras `publishableKey` y 10/10 tests. Se escribe el paso 1 de la parte 3 (Home).

- **2026-11-09** — Parte 2 verificada (format OK, 10/10 tests). `flutter analyze` solo avisó que `anonKey` está deprecado: se pasó a `publishableKey` (`--dart-define=SUPABASE_PUBLISHABLE_KEY=...`; `SUPABASE_ANON_KEY` sigue valiendo como alias). Modo desarrollador de Windows: activado.
- **2026-11-09** — Verificado en la máquina del usuario: `flutter pub get` OK (supabase_flutter 2.18.3), `flutter analyze` sin issues, `flutter test` 10/10. Windows pide activar Modo desarrollador (symlinks) para compilar con plugins. Se escribe la parte 2 de la Fase 2.

- **2026-11-09** — Fase 2 (parte 1): config, dependencia, modelos nuevos, `Song.fromJson`, interfaces y fakes de Song/Band. Sin compilar: correr `flutter pub get`, `dart format .`, `flutter analyze`, `flutter test` y corregir lo que salga.

- **2026-11-09** — Fase 1 VALIDADA: 0001–0004, seed.sql y rls_checks.sql corridos en Supabase sin errores. Se inicia la Fase 2 (lectura de `lib/`).
- **2026-11-09** — Proyecto Supabase `streamtunes` creado; `0001_schema.sql` ejecutado OK. `0002_rls.sql` dio error 42710 (policy ya existe) al re-ejecutarlo: se hizo idempotente (borra policies de `public` al inicio). Pendiente: correr 0002 de nuevo, luego 0003, 0004, seed y tests.
- **2026-11-09** — Fase 1 completa a nivel código: migraciones 0001–0004, `seed.sql`, `tests/rls_checks.sql`.
- **2026-11-09** — Se crea este archivo. Se inicia la Fase 1.

## PRÓXIMO PASO
1. **Entrega y Defensa Oral del Proyecto:**
   - Realizar la demostración en vivo siguiendo el guion cronológico de 10 minutos detallado en `INFORME_FINAL_Y_DEFENSA.md`.
   - Utilizar las credenciales de prueba preconfiguradas (`admin@`, `ana@`, `beto@`, `caro@`).
   - Mantener el comando `flutter run -d chrome --dart-define=USE_MOCK=true` como respaldo de contingencia si no hay internet en el aula.
