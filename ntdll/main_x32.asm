
; Forcing 32-bit addresses reduces program size.

include 'syscall.g', SYSCALL_BUILD equ "22621" ; change to your system build
include 'NtDef.g'

{bss:8} hStdOut dq ?

public mainCRTStartup as 'mainCRTStartup' ; linker expects this default name
mainCRTStartup:
	mov [rsp + 8], rbp
	mov ebp, esp

	{data:8} .allocationSize dq 2048
	{bss:16} .status IO_STATUS_BLOCK

	{data:2} .filename du '\??\CONOUT$',0
	{data:2} .filename.bytes := $ - .filename - 2
	{data:2} .filename.buffer := $ - .filename

	{data:64} .filenameU UNICODE_STRING \
		Length: .filename.bytes,\
		MaximumLength: .filename.buffer,\
		Buffer: .filename

	{data:64} .attributes OBJECT_ATTRIBUTES64 \
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
	push .allocationSize
	sub esp, 8*5 ; shadow space, return address placeholder
	lea r9, [.status]
	lea r8, [.attributes]
	mov edx, GENERIC_WRITE ; DesiredAccess
	lea r10, [hStdOut]
	syscall NtCreateFile
	mov esp, ebp ; add esp, 8*(5+7)

{data:1} .message db "Hello, World!"
{data:1} .message.bytes := $ - .message
{data:8} .byte_offset dq 0

	push 0				; PULONG key, optional
	push .byte_offset		; byte offset
	push .message.bytes		; length
	push .message			; buffer
	push .status			; PIO_STATUS_BLOCK
	sub esp, 8*5 ; shadow space, return address placeholder
	xor r9, r9			; PVOID ApcContext, optional
	xor r8, r8			; PIO_APC_ROUTINE ApcRoutine, optional
	xor edx, edx			; HANDLE event, optional
	mov r10, [hStdOut]
	syscall NtWriteFile
	mov esp, ebp ; add esp, 8*(5+5)

	mov rbp, [rsp + 8]
; Reusing the stack frame setup during process creation:

	mov r10, [hStdOut]
	syscall NtClose

	xor edx, edx ; NTSTATUS
	assert NtCurrentProcess = -1
	or r10, NtCurrentProcess ; HANDLE, optional
	syscall NtTerminateProcess
	jmp $


virtual as "response" ; configure linker from here
	db '/NOLOGO',10
;	db '/VERBOSE',10 ; use to debug build process
	db '/RELEASE',10 ; set program checksum in header
	db '/NODEFAULTLIB',10
	db '/IGNORE:4281',10 ; ASLR doesn't happen for /FIXED!
	db '/FIXED',10 ; don't generate relocation information
;	db '/DYNAMICBASE:NO',10 ; same as /FIXED
	db '/BASE:0x10000',10
	db '/SUBSYSTEM:CONSOLE',10

; UNDOCUMENTED: no POGO debug info stored, corrupts sections?
	db '/EMITPOGOPHASEINFO',10
	db '/MERGE:.rdata=.text',10 ; needed to prevent corruption.
; todo: what is the 64-bytes still present in .rdata?

; DLLs are loaded into 32-bit address space (ntdll still high!)
;	db '/LARGEADDRESSAWARE:NO',10

;	db '/HEAP:reserve,commit',10
;	db '/STACK:reserve,commit',10

	db '/HIGHENTROPYVA:NO',10
	db '/GUARD:NO',10 ; requires /DYNAMICBASE
	db '/CETCOMPAT:NO',10

;	db '/DELAYLOAD:kernel32.dll',10
;	db '/DEPENDENTLOADFLAG:0x800',10 ; LOAD_LIBRARY_SEARCH_SYSTEM32
end virtual
