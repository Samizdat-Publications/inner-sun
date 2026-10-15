@echo off
rem Plays the current build of Inner Sun with the Godot editor binary (the M0 fire drill scene).
rem Once Milestone 1 ships a playtest build, this launches builds\InnerSun.exe instead.
cd /d "%~dp0"
if exist "builds\InnerSun.exe" (
  if exist "builds\PLAYTEST" (
    start "" "builds\InnerSun.exe"
    exit /b 0
  )
)
set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe"
if not exist "%GODOT%" (
  echo Godot 4.7.2 was not found at %GODOT%
  echo Install it with: winget install GodotEngine.GodotEngine
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0game"
