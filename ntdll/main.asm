include 'windows.g'
;	fasm2 main.asm
;	link @main.response main.obj

public WinMainCRTStartup as 'WinMainCRTStartup' ; linker expects this default name
:WinMainCRTStartup:

; https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntcreatefile

{const:2} .filename du '\??\CONOUT$',0
{const:2} .filename.bytes := $ - .filename - 2
{const:2} .filename.buffer := $ - .filename

{const:64} .filenameU UNICODE_STRING .filename.bytes,.filename.buffer,.filename
{const:64} .attributes OBJECT_ATTRIBUTES Length: sizeof OBJECT_ATTRIBUTES,\
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
	mov eax, 55h ; NtCreateFile
	syscall NtCreateFile
	add rsp, 8*(5+7)


	mov eax, NtWriteFile
	syscall NtWriteFile
	add rsp, 8*(5+7)


	mov eax, NtTerminateProcess
	syscall NtTerminateProcess
	add rsp, 8*(5+7)




struct UNICODE_STRING
	dw ?
	dw ?
	__0 rb 4
	dq ?
ends

struct OBJECT_ATTRIBUTES
	Length			dd ?,?	; ULONG
	RootDirectory		dq ?	; HANDLE
	ObjectName		dq ?	; PUNICODE_STRING
	Attributes		dd ?,?	; ULONG
	SecurityDescriptor	dq ?	; PSECURITY_DESCRIPTOR
	SecurityQualityOfService dq ?	; PSECURITY_QUALITY_OF_SERVICE
ends





hStdOut 	dq ?
status		dq ?,? ; Status, Information
allocationSize	dq 2048

attributes	dq sizeof attributes
	dq 0
	dq fnameUStr
	dq OBJ_CASE_INSENSITIVE or OBJ_INHERIT
	dq 0
	dq 0

fnameUStr:
	dw filenameSz

filename du '\??\CONOUT$',0
filenameSz := $ - filename - 2



	jmp $


; configure linker from here
virtual as "response"
	db '/NOLOGO',10
;	db '/VERBOSE',10 ; use to debug process
	db '/NODEFAULTLIB',10
	db '/SUBSYSTEM:CONSOLE',10
end virtual
