@echo off
title StreamTunes - Servidor Web Local
cd /d "%~dp0.."
if not exist "build\web" (
  echo ========================================================
  echo   No se encontro build\web. Compilando PWA en modo demo...
  echo ========================================================
  call flutter build web --dart-define=USE_MOCK=true
  if errorlevel 1 (
    echo Error durante la compilacion web.
    pause
    exit /b %errorlevel%
  )
)
cd /d "%~dp0..\build\web"
echo ========================================================
echo   Abriendo StreamTunes Web...
echo   URL: http://localhost:8080
echo ========================================================
start http://localhost:8080
python -m http.server 8080
pause
