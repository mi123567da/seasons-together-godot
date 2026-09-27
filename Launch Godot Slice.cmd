@echo off
set "GODOT_EXE=E:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot 4.7+ was not found at:
  echo %GODOT_EXE%
  echo Install Godot or open project.godot from the Godot Project Manager.
  pause
  exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0"
