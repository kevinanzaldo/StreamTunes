@echo off
title StreamTunes - Modo Demo Offline
echo ========================================================
echo   Iniciando StreamTunes en Modo Demo (Offline)...
echo   Para defensa o prueba sin conexion a internet
echo ========================================================
flutter run -d chrome --dart-define=USE_MOCK=true
pause

