@echo off
setlocal EnableDelayedExpansion EnableExtensions

if [%1] == [] (
  echo [USAGE] List of files expected.
  goto end
)

:try
if not exist "%1" (
  echo [FAIL] File not found. "%1"
  goto :end
)

set "SOURCE=%1"
set "OUTPUT=%1.temp"

fasmg -n -v 2 -e 5 "%SOURCE%" "%OUTPUT%"
if errorlevel 1 (
  echo [FAIL] Assembly failed. "%SOURCE%"
  goto :end
)

fc /B "%SOURCE%" "%OUTPUT%" >nul
if errorlevel 1 (
  echo [FAIL] Differences found. Not a quine. "%SOURCE%"
  REM	Don't remove output so user can debug.
  goto :end
) else (
  echo [SUCCESS] Perfect Quine^^^! Source and Output match in "%SOURCE%"
  del "%OUTPUT%"
)

shift /1
if [%1] NEQ [] goto :try

:end
endlocal
