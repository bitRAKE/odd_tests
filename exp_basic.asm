
; basic table based exception handling
;	fasm2.cmd except.asm
;	link @except.response

format MS64 COFF
extrn '__imp_MessageBoxA' as MessageBoxA:QWORD
extrn '__imp_ExitProcess' as ExitProcess:QWORD
public Main

section '.text' code readable executable align 64

Message db 'OK to rethrow, CANCEL to generate core dump.',0
Caption db 'SEGV',0

align 64, 90h ; NOPs
Handler:
; RCX: EXCEPTION_RECORD
; RDX: ULONG64, base of fixed stack allocation for this function
;  R8: CONTEXT64
;  R9: DISPATCHER_CONTEXT
	enter 32, 0
	xor ecx, ecx
	lea rdx, [Message]
	lea r8, [Caption]
	mov r9d, 1 ; MB_OKCANCEL
	call [MessageBoxA]
	dec eax ; incidentally suits as return value for exception handler
	leave
	retn


Main:	mov al, [dword 0] ; cause exception

	xor ecx, ecx
	call [ExitProcess]
	jmp $
	.end:


; part of Exception Directory:  IMAGE_DIRECTORY_ENTRY_EXCEPTION(3)
section '.pdata' data readable align 4 ; RUNTIME_FUNCTION structures
	dd RVA Main		; function start
	dd RVA Main.end		; function end
	dd RVA Main.unwind	; function UNWIND_INFO



section '.xdata' data readable align 8 ; UNWIND_INFO structures
Main.unwind:
	db 9,0,0,0
	dd RVA Handler



virtual as "response" ; configure linker from here:
	db '/NOLOGO',10

; Use to debug process:
;	db '/VERBOSE',10
;	db '/TIME+',10

; Create unique binary using image version and checksum:
	repeat 1,T:__TIME__ shr 16,t:__TIME__ and 0xFFFF
		db '/VERSION:',`T,'.',`t,10
	end repeat
	db '/RELEASE',10		; set program checksum in header

	db '/NODEFAULTLIB',10		; all dependencies explicit, below
	db '/ENTRY:Main',10
	db '/SUBSYSTEM:WINDOWS,6.02',10	; Win8+
	db 'kernel32.lib',10
	db 'user32.lib',10

;:HACK, to set the output file name and shorten link command:
	db (((__FILE__ bswap lengthof __FILE__) and not $FFFFFF) or 'jbo') bswap lengthof __FILE__
end virtual
