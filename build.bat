@echo off
rem Atomic Bombs - export a standalone Windows build (release, single .exe with embedded data).
rem Output: build\AtomicBombs\AtomicBombs.exe (+ AtomicBombs.console.exe, which shows the log).
rem Needs Godot 4.7.2 and its export templates (Editor > Manage Export Templates).
rem Godot: uses %GODOT% if set, else the known install path, else searches PATH.
setlocal
cd /d "%~dp0"
if defined GODOT if exist "%GODOT%" goto build
set "GODOT=W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto build
for %%G in (Godot_v4.7.2-stable_win64.exe godot.exe godot4.exe) do (
  for %%P in (%%~$PATH:G) do if not "%%P"=="" ( set "GODOT=%%P" & goto build )
)
echo Godot 4.7.2 not found. Set the GODOT environment variable to Godot_v4.7.2-stable_win64.exe
pause
exit /b 1
:build
rem The console variant of the editor prints the export log into this window.
for %%F in ("%GODOT%") do set "GODOT_CON=%%~dpnF_console%%~xF"
if exist "%GODOT_CON%" set "GODOT=%GODOT_CON%"
if not exist "build\AtomicBombs" mkdir "build\AtomicBombs"
if not exist ".godot\global_script_class_cache.cfg" "%GODOT%" --headless --path "%CD%" --import
"%GODOT%" --headless --path "%CD%" --export-release "Windows Desktop" "build/AtomicBombs/AtomicBombs.exe"
if errorlevel 1 (
  echo BUILD FAILED
  exit /b 1
)
if not exist "build\AtomicBombs\AtomicBombs.exe" (
  echo BUILD FAILED: build\AtomicBombs\AtomicBombs.exe was not created
  exit /b 1
)
echo BUILD OK: %CD%\build\AtomicBombs\AtomicBombs.exe
endlocal
