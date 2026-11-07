@echo off
rem Atomic Bombs - launch the game windowed.
rem Godot 4.7.2: uses %GODOT% if set, else the known install path, else searches PATH.
setlocal
cd /d "%~dp0"
if defined GODOT if exist "%GODOT%" goto run
set "GODOT=W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto run
for %%G in (Godot_v4.7.2-stable_win64.exe godot.exe godot4.exe) do (
  for %%P in (%%~$PATH:G) do if not "%%P"=="" ( set "GODOT=%%P" & goto run )
)
echo Godot 4.7.2 not found. Set the GODOT environment variable to Godot_v4.7.2-stable_win64.exe
pause
exit /b 1
:run
if not exist ".godot\global_script_class_cache.cfg" "%GODOT%" --headless --path "%~dp0" --import
start "" "%GODOT%" --path "%~dp0" %*
endlocal
