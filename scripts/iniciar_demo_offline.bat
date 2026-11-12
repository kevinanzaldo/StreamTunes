@echo off
title StreamTunes - Modo Demo Offline
cd /d "%~dp0.."
echo ========================================================
echo   Iniciando StreamTunes en Modo Demo (Offline)...
echo   Para defensa o prueba sin conexion a internet
echo ========================================================
flutter run -d chrome --dart-define=USE_MOCK=true
pause
