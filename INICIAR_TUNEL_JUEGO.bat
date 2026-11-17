@echo off
title Cloudflare Tunnel - Uma Party Dash Server
color 0B
echo ======================================================================
echo           INICIANDO TUNEL PUBLICO PARA UMA PARTY DASH
echo ======================================================================
echo.
echo  1. Inicia el juego en tu PC y selecciona:
echo     "Modo Red: Web & Online (WebSocket)"
echo  2. Pulsa "CREAR SALA (HOST)"
echo.
echo  Conectando con Cloudflare...
echo  Copia la URL que termine en ".trycloudflare.com" (ej: https://xxxx.trycloudflare.com)
echo  y pasasela a tus amigos o ingresala en la casilla de IP en Itch.io!
echo ======================================================================
echo.

"E:\Tools\cloudflared\cloudflared.exe" tunnel --url http://localhost:8080
pause
