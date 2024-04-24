
; test linker section merging and alignment
;
; will the linker merge sections in the correct order and respect alignment
;	14.39.33523.0
;	+ section name sorting is not required, alignment still handled correctly
; 

format MS64 COFF

; Section naming follows alignment required:
;	postfix		alignment
;	'$n'		4096
;	'$o'		2048
;	'$p'		1024
;	'$q'		512
;	'$r'		256
;	'$s'		128
;	'$t'		64
;	'$u'		32
;	'$v'		16
;	'$w'		8
;	'$x'		4
;	'$y'		2
;	'$z'		1
; Linker sorting respects alignment and merges similarly named sections.

calminstruction generator alignment*
	local result,index,alpha
	compute result, alignment
	compute index, bsf result
	compute alpha, 'z' - index
	arrange alpha, =string alpha
	arrange result, result
	stringify result
	asm virtual as alpha
	asm db "format MS64 COFF",10
	asm db "section '.const$",alpha,"' data readable align ",result,10
	asm db "public ",alpha,10
	asm db alpha," db '",alpha,"'",10
	asm end virtual
end calminstruction

repeat 13
	generator 1 shl (%-1)
end repeat

;🟪🟥🟧🟨🟩🟦🟩🟨🟧🟥🟪🟥🟧🟨🟩🟦🟩🟨🟧🟥🟪🟥🟧🟨🟩🟦🟩🟨🟧🟥🟪

section '.text' code readable executable align 16

message db 'Hello, World!'
message.characters := $ - message

repeat 13
	eval "extrn '",'m'+%,"' as ?",`%
	dq ?%
end repeat


extrn ExitProcess
extrn GetStdHandle
extrn WriteConsoleA

public Main as 'mainCRTStartup' ; linker expects this default name
Main:
	push rax
	virtual at rsp
				rq 4	; shadow space for callee
		.lpReserved	dq ?
	end virtual
	mov ecx, -11 ; STD_OUTPUT_HANDLE
	call GetStdHandle
	xchg rcx, rax
	lea rdx, [message]
	mov r8, message.characters
	xor r9, r9 ; optional, lpNumberOfCharsWritten
	mov [.lpReserved], r9
	call WriteConsoleA

	; process exit code
	xor ecx, ecx
	call ExitProcess
	int3
