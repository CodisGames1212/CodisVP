@echo off
setlocal
cd /d "%~dp0.."
if "%FFMPEG_ROOT%"=="" set "FFMPEG_ROOT=%CD%\third_party\ffmpeg\ffmpeg-n8.1-latest-win64-lgpl-shared-8.1"
if not exist "%FFMPEG_ROOT%\include\libavcodec\avcodec.h" (
  echo Set FFMPEG_ROOT to a shared FFmpeg development SDK or run tools/setup_windows.ps1.
  exit /b 1
)
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64
if errorlevel 1 exit /b %errorlevel%
set "PATH=C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
cmake -S . -B build-ninja -G Ninja -DCMAKE_BUILD_TYPE=Release -DFFMPEG_ROOT="%FFMPEG_ROOT%"
if errorlevel 1 exit /b %errorlevel%
cmake --build build-ninja --parallel 6
exit /b %errorlevel%
