@echo off
rem Doble clic o `play.bat [-Rebuild] [-NoLaunch]`: construye si hace falta y abre el juego (ver scripts\play.ps1).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\play.ps1" %*
if errorlevel 1 pause
