
include 'syscall.g', SYSCALL_BUILD equ "22621" ; change to your system build
include 'NtDef.g'

;	fasm2 main.asm
;	link @main.response main.obj

{bss:8} hStdOut dq ?

public mainCRTStartup as 'mainCRTStartup' ; linker expects this default name
mainCRTStartup:

	{data:8} .allocationSize dq 2048
	{bss:16} .status IO_STATUS_BLOCK

	{const:2} .filename du '\??\CONOUT$',0
	{const:2} .filename.bytes := $ - .filename - 2
	{const:2} .filename.buffer := $ - .filename

	{const:64} .filenameU UNICODE_STRING \
		Length: .filename.bytes,\
		MaximumLength: .filename.buffer,\
		Buffer: .filename

	{const:64} .attributes OBJECT_ATTRIBUTES64 \
		Length: sizeof .attributes,\
		ObjectName: .filenameU,\
		Attributes: OBJ_CASE_INSENSITIVE or OBJ_INHERIT

; Note: SYSCALLs differs from standard fastcall in that `R10 is used instead
; of `RCX, space for a return address on the stack is expected.
;
;	virtual at RSP
;		.RET	dq ?	; unused space needed
;			rq 4	; shadow space
;		.P4	dq ?
;		...
;	end virtual

	xor ecx, ecx
	push rcx ; EaLength
	push rcx ; EaBuffer
	push FILE_NON_DIRECTORY_FILE ; CreateOptions
	push FILE_OPEN ; CreateDisposition
	push FILE_SHARE_READ or FILE_SHARE_WRITE ; ShareAccess
	push FILE_ATTRIBUTE_NORMAL ; FileAttributes
	lea rax, [.allocationSize]
	push rax ; AllocationSize
	sub rsp, 8*5 ; shadow space, return address placeholder
	lea r9, [.status]
	lea r8, [.attributes]
	mov edx, GENERIC_WRITE ; DesiredAccess
	lea r10, [hStdOut]
	syscall NtCreateFile
	add rsp, 8*(5+7)

{const:1} .message db "Hello, World!"
{const:1} .message.bytes := $ - .message
{const:8} .byte_offset dq 0

	lea rax, [.byte_offset]
	lea rcx, [.message]
	lea rdx, [.status]
	push 0				; PULONG key, optional
	push rax			; byte offset
	push .message.bytes		; length
	push rcx			; buffer
	push rdx			; PIO_STATUS_BLOCK
	sub rsp, 8*5 ; shadow space, return address placeholder
	xor r9, r9			; PVOID ApcContext, optional
	xor r8, r8			; PIO_APC_ROUTINE ApcRoutine, optional
	xor edx, edx			; HANDLE event, optional
	mov r10, [hStdOut]
	syscall NtWriteFile
	add rsp, 8*(5+5)

; Reusing the stack frame setup during process creation:

	mov r10, [hStdOut]
	syscall NtClose

	xor edx, edx ; NTSTATUS
	mov r10, NtCurrentProcess ; HANDLE, optional
	syscall NtTerminateProcess
	jmp $


; configure linker from here
virtual as "response"
	db '/NOLOGO',10
;	db '/VERBOSE',10 ; use to debug process
	db '/NODEFAULTLIB',10
	db '/SUBSYSTEM:CONSOLE',10
end virtual
