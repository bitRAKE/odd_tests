@echo off
REM	include_order.cmd -- Test include path search order:
REM	(assumes fasmg in environment)
setlocal
if "%*"=="" (
	set "TEST=fasmg -n ../test.asm"
) else (
	REM Test various pathspecs of fasm[g|2]
	set "TEST=%*"
)

mkdir io_file
mkdir io_cwd
mkdir io_env

REM __SOURCE__
echo include 'io_file/test.inc' >test.asm
REM __FILE__
echo include 'test_path.inc' >io_file/test.inc

echo display '1. __FILE__ path superceeds all others' >io_file/test_path.inc
echo display '2. current working directory' >io_cwd/test_path.inc
echo display '3. %%include%% environment variable paths' >io_env/test_path.inc
echo display '4. __SOURCE__ path, command line file location' >test_path.inc

REM	1. __FILE__ path superceeds all others
set "include=%~dp0io_env"
pushd io_cwd
%TEST%
del ..\io_file\test_path.inc
pause > nul

REM	2. current working directory
%TEST%
del test_path.inc
pause > nul

REM	3. %include% environment variable paths
%TEST%
set "include="
pause > nul

REM	4. __SOURCE__ path, command line file location
%TEST%
popd

REM various default output filenames
del test 2>nul
del test.bin 2>nul

del test.asm
del test_path.inc
del io_file\test.inc
del io_env\test_path.inc
rmdir io_file
rmdir io_cwd
rmdir io_env
endlocal
