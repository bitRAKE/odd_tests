@echo off
setlocal
set fasm2=c:\fasm2\fasm2.cmd

echo /IGNORE:4281 > response
echo /FIXED >> response
echo /BASE:0x10000 >> response
echo /SUBSYSTEM:CONSOLE >> response
echo /DEFAULTLIB:KERNEL32.LIB >> response
call %fasm2% merge.asm
echo merge.obj >> response

for %%i in (n o p q r s t u v w x y z) do (
	call %fasm2% merge.%%i %%i.obj
	echo %%i.obj >> response
)

link @response

if errorlevel 0 (
	del merge.obj
	FOR %%i IN (n o p q r s t u v w x y z) DO (
		del merge.%%i
		del %%i.obj
	)
	del response
)
endlocal