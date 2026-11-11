@echo off
title StreamTunes - Conectado a Supabase
cd /d "%~dp0"
if not exist "env.json" (
  echo ========================================================
  echo   Falta el archivo env.json en StreamTunes\
  echo   Copia env.example.json como env.json y completa
  echo   SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY.
  echo   O usa iniciar_demo_offline.bat para el modo demo.
  echo ========================================================
  pause
  exit /b 1
)
echo ========================================================
echo   Iniciando StreamTunes conectado a Supabase (env.json)...
echo ========================================================
flutter run -d chrome --dart-define-from-file=env.json
pause
