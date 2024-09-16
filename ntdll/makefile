fasm2 = C:\_daily\asmgame\fasm2.cmd

.SUFFIXES : .asm.obj

.asm.obj :
	$(fasm2) -e 5 $<
	@if not exist $(<:.asm=.obj) exit 1


all : main.exe main_x32.exe tidy


main.exe : main.obj
	link @$*.response $**

main.response : main.obj


main_x32.exe : main_x32.obj
	link @$*.response $**

main_x32.response : main_x32.obj



.SILENT :

tidy :
	del /S /Q *.obj *.response >NUL 2>&1

clean : tidy
	del /S /Q *.exp *.lib *.dll *.exe *.zip >NUL 2>&1

#package : clean
#	tar -a -cf main.zip --exclude=main.zip *
