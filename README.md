# StreamTunes 🎵

Plataforma de streaming de música para bandas independientes y música under. Desarrollada en **Flutter (PWA & Móvil)** con backend en **Supabase (PostgreSQL 15, RLS, Storage y Realtime)**.

---

## 📌 Documentación del Proyecto

- 📘 [**Plan Maestro (`STREAMTUNES_PLAN_MAESTRO.md`)**](STREAMTUNES_PLAN_MAESTRO.md): Requerimientos del cliente (Kiwi Delmonte), arquitectura, esquema de base de datos SQL y mapeo contra la grilla de evaluación EGI.
- 📋 [**Progreso y Checkpoints (`PROGRESO.md`)**](PROGRESO.md): Bitácora de trabajo fase por fase con métricas de tests y decisiones de diseño.
- 🎓 [**Informe Final y Guía de Defensa (`INFORME_FINAL_Y_DEFENSA.md`)**](INFORME_FINAL_Y_DEFENSA.md): Mapeo exhaustivo de los 18 criterios de evaluación EGI, guion de demostración paso a paso y cotización de mantenimiento.

---

## 🚀 Cómo Ejecutar la Aplicación

### 1. Modo Demo Offline (Respaldo para Defensa / Sin Internet)
Ejecuta la app con repositorios en memoria completamente aislados:
```bash
flutter run -d chrome --dart-define=USE_MOCK=true
```

### 2. Modo Conectado a Supabase (Producción / Prueba)
1. Copiar `env.example.json` como `env.json` en la raíz del proyecto y completar `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` (archivo ignorado por Git).
2. Ejecutar con `--dart-define-from-file=env.json` (también usado por `scripts/iniciar.bat` y `.vscode/launch.json`):
```bash
flutter run -d chrome --dart-define-from-file=env.json
```
*(Alternativamente, se pueden pasar `--dart-define=SUPABASE_URL=...` y `--dart-define=SUPABASE_PUBLISHABLE_KEY=...` por CLI).*

Si usás migraciones por columna en Supabase, aplicá también manualmente `supabase/migrations/0006_song_id_and_cover_grants.sql` en el **SQL Editor** del proyecto antes de publicar temas nuevos con UUID generado en cliente y portada.

### 3. Compilación para la Web (PWA)
```bash
flutter build web --dart-define=USE_MOCK=true
```
Para servir la web localmente, `scripts/ver_web_local.bat` levanta el servidor HTTP y, si no encuentra `build/web/`, lo compila automáticamente en modo demo antes de abrirlo.

### 4. Compilación Android Release y Firma (`apk`)

Por defecto, si no existe `android/key.properties`, el build de release cae a la firma `debug` para que `flutter run --release` siga funcionando en desarrollo. Para firmar un APK real de distribución:

1. Generar la keystore (ejemplo en `android/app/upload-keystore.jks`):
   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copiar `android/key.properties.example` como `android/key.properties` y completar las contraseñas, alias y ruta (`storeFile=upload-keystore.jks`). Ambos archivos (`key.properties` y `*.jks`) están ignorados por Git.
3. Compilar el APK release (usando `env.json` o `--dart-define=USE_MOCK=true`):
   ```bash
   flutter build apk --release --dart-define-from-file=env.json
   ```

---

## 📱 Qué se puede demostrar dónde

| Funcionalidad / Criterio | Android físico | Web (Chrome / PWA) |
|---|---|---|
| Flujo completo (audio, Storage, RLS, Realtime, Isolate/compute) | ✅ Completo | ✅ Completo |
| Cámara (`D1`) | ✅ Captura real con cámara | ℹ️ Solo selector de galería |
| Notificaciones locales (`E1`) | ✅ Notificación nativa Android | ⚠️ No disponible en navegador → respaldo `SnackBar` in-app |
| Tareas en segundo plano (`E2`, Workmanager) | ✅ Isolate nativo post-publicación (con subida pesada en primer plano) | ⚠️ No soportado en navegador → confirmación visual in-app |
| Foco de audio / llamadas (`E3`) | ✅ `audio_session` nativo | ℹ️ Controlado por políticas del navegador |

---

## 🧪 Pruebas y Calidad de Código

El proyecto cuenta con **110 tests automatizados** pasando al 100% (`flutter test`), **0 issues** en `flutter analyze` y formato aplicado en los **94 archivos** Dart del proyecto:

```bash
# Formateo de código
dart format .

# Análisis estático (modo estricto)
flutter analyze

# Suite completa de tests
flutter test
```

---

## 👥 Cuentas Demo de Prueba (`seed.sql`)

> ⚠️ **ADVERTENCIA DE SEGURIDAD:** `supabase/seed.sql` crea 4 usuarios de prueba (incluida la administradora `admin@streamtunes.test`) con la contraseña conocida `Test1234!`. **NO debe ejecutarse nunca en un proyecto Supabase de producción o real** — solo en entornos locales o de pruebas.  
> Si ya se ejecutó en un proyecto compartido/real, entrá al panel de Supabase para **cambiar la contraseña de la administradora** (o eliminar las cuentas demo) y considerá **rotar la clave `SUPABASE_PUBLISHABLE_KEY`**.

| Email | Contraseña | Rol y Acceso |
|---|---|---|
| `admin@streamtunes.test` | `Test1234!` | **Moderadora del Colectivo** (Panel de Moderación) |
| `ana@streamtunes.test` | `Test1234!` | **Música (Dueña)** de *Los Subterráneos* (Panel "Mi banda") |
| `beto@streamtunes.test` | `Test1234!` | **Músico (Colaborador)** de *La Trinchera* |
| `caro@streamtunes.test` | `Test1234!` | **Oyente** (sin banda, escucha y realiza donaciones) |

---

## 🏛️ Arquitectura del Software

- **Capas limpias:** `Models` → `Repositories (Interfaces)` → `Services` → `ViewModels (ChangeNotifier)` → `Views/Widgets`.
- **Gestión de Estado:** `ChangeNotifier` + `ListenableBuilder` + Scopes nativos (`SessionScope`, `RepositoriesScope`, `LibraryScope`, `ReproductorScope`).
- **Concurrencia:** Cálculos pesados de 50.000 registros con `Isolate.run` (nativo) / `compute` (web); donaciones en tiempo real con Supabase Realtime / Streams.
- **Seguridad:** Row Level Security (RLS) en 14 tablas, permisos por columna y triggers PL/pgSQL para cuotas de temas y control de gasto.
