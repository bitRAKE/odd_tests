fasm2 = c:\fasm2\fasm2.cmd

.SUFFIXES : .asm.obj

.asm.obj :
	$(fasm2) -e 5 $<


all : dll.dll main.exe

main.exe : main.obj
	link @main.response $**

main.response : main.obj

dll.dll : dll.obj
	link @dll.response $**

dll.response : dll.obj



.SILENT :

clean :
	del /S /Q *.obj >NUL 2>&1
	del /S /Q *.exp >NUL 2>&1
	del /S /Q *.lib >NUL 2>&1
	del /S /Q *.response 2>NUL 2>&1
	del /S /Q *.exe 2>NUL 2>&1
	del /S /Q *.dll 2>NUL 2>&1
	del /S /Q *.zip 2>NUL 2>&1
