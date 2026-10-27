@echo off
rem ============================================================
rem  GodotPVZ-Dream launcher
rem  Double-click          : start the game (no editor)
rem  Add "editor" argument : open the Godot editor instead
rem
rem  This file is intentionally ASCII-only: a .bat containing
rem  Chinese text gets decoded with the console code page and can
rem  break on machines whose code page is not 936.
rem ============================================================
setlocal EnableExtensions

rem Project root = folder containing this .bat, without trailing backslash
set "PROJ=%~dp0"
if "%PROJ:~-1%"=="\" set "PROJ=%PROJ:~0,-1%"

rem Path to the Godot executable; edit this line on another machine
set "GODOT=D:\AItool\Godot\Godot_v4.7.2-stable_win64.exe"

if not exist "%GODOT%" (
  echo [ERROR] Godot executable not found:
  echo         %GODOT%
  echo         Edit this file and fix the GODOT variable.
  pause
  exit /b 1
)

if not exist "%PROJ%\project.godot" (
  echo [ERROR] project.godot not found next to this file:
  echo         %PROJ%
  pause
  exit /b 1
)

rem "editor" argument opens the editor, otherwise run the main scene
if /i "%~1"=="editor" (
  start "" "%GODOT%" --path "%PROJ%" --editor
) else (
  start "" "%GODOT%" --path "%PROJ%"
)

exit /b 0