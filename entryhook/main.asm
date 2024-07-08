include 'windows.g'
;	fasm2 main.asm
;	link @main.response main.obj

extrn 'Add'		as _Add	; int Add(int a, int b);
extrn 'Subtract'	as _Sub	; int Subtract(int a, int b);

public WinMainCRTStartup as 'WinMainCRTStartup' ; linker expects this default name
:WinMainCRTStartup:
	pop rax ; no return

	MessageBoxA 0, A "Hello, World!", A "Try", MB_OK

	fastcall _Add, -1, -2
	xchg ecx, eax
	fastcall _Sub, ecx, -3
	xchg ecx, eax
	ExitProcess ecx
	jmp $


; configure linker from here
virtual as "response"
	db '/NOLOGO',10
;	db '/VERBOSE',10 ; use to debug process
	db '/NODEFAULTLIB',10
	db '/SUBSYSTEM:WINDOWS,6.02',10
	db 'kernel32.lib',10
	db 'user32.lib',10
	db 'dll.lib',10
end virtual
