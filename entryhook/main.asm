include 'windows.g'
;	fasm2 main.asm
;	link @main.response main.obj

extrn '?Add@@YAHHH@Z'		as _Add		; int Add(int a, int b);
extrn '?Subtract@@YAHHH@Z'	as _Sub		; int Subtract(int a, int b);

public _DllMainCRTStartup as '_DllMainCRTStartup' ; linker expects this default name
:_DllMainCRTStartup:
	cmp edx, DLL_PROCESS_ATTACH
	jnz @1F

	enter .frame, 0
	GetModuleHandleA A "ntdll"
	xchg rcx, rax
	GetProcAddress rcx, A "RtlUserThreadStart"
	mov [original_RtlUserThreadStart], rax

	lea rdx, [__ImageBase]
	mov ecx, [rdx + IMAGE_DOS_HEADER.e_lfanew]
	mov ecx, [rdx + rcx + IMAGE_OPTIONAL_HEADER64.AddressOfEntryPoint]
	add rdx, rcx

	mov ecx, 0x1000 ; search range
@@:	cmp [rbp + rcx + CONTEXT.Rip], rax ; original_RtlUserThreadStart
	jnz @9F
	cmp [rbp + rcx + CONTEXT.Rcx], rdx ; entryPoint
@9:	loopnz @B
	jnz @2F ; Y: not found, skip hook

	lea rax, [hook_RtlUserThreadStart]
	mov [rbp + rcx + CONTEXT.Rip], rax
@2:	leave
@1:	mov eax, 1
	retn


; configure linker from here
virtual as "response"
;	db '/VERBOSE',10 ; use to debug process
	db '/NODEFAULTLIB',10
	db '/SUBSYSTEM:WINDOWS,6.02',10
	db 'kernel32.lib',10
	db 'user32.lib',10
	db 'dll.lib',10
end virtual
