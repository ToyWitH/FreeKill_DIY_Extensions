@echo off
if exist "%~dp0FreeKill\FreeKill.exe" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0FreeKill\update-sunjiale.ps1"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-sunjiale.ps1"
)
pause
