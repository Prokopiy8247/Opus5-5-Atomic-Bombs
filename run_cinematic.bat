@echo off
rem Atomic Bombs - offline cinematic render (Godot Movie Maker): PNG sequence + WAV.
rem Usage: run_cinematic.bat [bomb 1-20] [seconds] [resolution] [tod] [view]
rem   e.g. run_cinematic.bat 20 90 3840x2160 noon bunker
rem Output: movie\bNN_frame########.png + .wav  (assemble with ffmpeg, see README.md)
setlocal
cd /d "%~dp0"
set "BOMB=%~1"
if "%BOMB%"=="" set "BOMB=11"
set "SECS=%~2"
if "%SECS%"=="" set "SECS=60"
set "RES=%~3"
if "%RES%"=="" set "RES=3840x2160"
set "TOD=%~4"
if "%TOD%"=="" set "TOD=dawn"
set "VIEW=%~5"
if "%VIEW%"=="" set "VIEW=bunker"
if defined GODOT if exist "%GODOT%" goto run
set "GODOT=W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
if exist "%GODOT%" goto run
for %%G in (Godot_v4.7.2-stable_win64_console.exe Godot_v4.7.2-stable_win64.exe godot.exe) do (
  for %%P in (%%~$PATH:G) do if not "%%P"=="" ( set "GODOT=%%P" & goto run )
)
echo Godot 4.7.2 not found. Set the GODOT environment variable.
exit /b 1
:run
if not exist movie mkdir movie
set /a FRAMES=%SECS%*60
"%GODOT%" --path "%~dp0" --resolution %RES% --fixed-fps 60 --write-movie "movie\b%BOMB%_frame.png" --quit-after %FRAMES% -- --bomb %BOMB% --tod %TOD% --view %VIEW% --autolaunch
echo Done: movie\b%BOMB%_frame*.png
endlocal
