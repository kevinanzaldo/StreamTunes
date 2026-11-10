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
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=TU_PUBLISHABLE_KEY
```

### 3. Compilación para la Web (PWA)
```bash
flutter build web --dart-define=USE_MOCK=true
```

---

## 🧪 Pruebas y Calidad de Código

El proyecto cuenta con **89 tests automatizados** y 0 advertencias de linter:

```bash
# Formateo de código
dart format .

# Análisis estático (modo estricto)
flutter analyze

# Suite completa de tests
flutter test
```

---

## 👥 Cuentas Demo de Prueba

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
