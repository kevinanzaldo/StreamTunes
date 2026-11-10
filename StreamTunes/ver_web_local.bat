@echo off
title StreamTunes - Servidor Web Local (Inmediato)
cd /d "%~dp0build\web"
echo ========================================================
echo   Abriendo StreamTunes Web ya compilado...
echo   URL: http://localhost:8080
echo ========================================================
start http://localhost:8080
python -m http.server 8080
pause

