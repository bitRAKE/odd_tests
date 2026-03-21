@echo off
setlocal

set "SOURCE=%1"
set "OUTPUT=%1.temp"

fasmg -v 2 -e 5 "%SOURCE%" "%OUTPUT%"
if errorlevel 1 (
  echo [FAIL] Assembly failed.
  goto :end
)

fc /B "%SOURCE%" "%OUTPUT%" >nul
if errorlevel 1 (
  echo [FAIL] Differences found. Not a quine.
  REM	Don't remove output so user can debug.
) else (
  echo [SUCCESS] Perfect Quine! Source and Output match.
  del "%OUTPUT%"
)

:end
endlocal
