
calminstruction NtCurrentTeb reg*
	arrange reg, =mov reg,=qword [=gs:0x30]
	assemble reg
end calminstruction

; alternate:
;	NtCurrentTeb rax
;	mov rax, [rax + TEB.ProcessEnvironmentBlock] ; PEB

calminstruction NtCurrentPeb reg*
	arrange reg, =mov reg,=qword [=gs:0x60]
	assemble reg
end calminstruction

iterate <value, pseudo_handle>,\
	-1,	NtCurrentProcess,\
	-2,	NtCurrentThread,\
	-3,	NtCurrentSession,\
	-4,	NtCurrentProcessToken,\		; NtOpenProcessToken(NtCurrentProcess())
	-5,	NtCurrentThreadToken,\		; NtOpenThreadToken(NtCurrentThread())
	-6,	NtCurrentEffectiveToken,\	; NtOpenThreadToken(NtCurrentThread()) + NtOpenProcessToken(NtCurrentProcess())
	-1,	NtCurrentSilo

	pseudo_handle:=value
	calminstruction pseudo_handle
		err 'use pseudo-handle ' bappend `value bappend ' for ' bappend `pseudo_handle
	end calminstruction
end iterate

;#define NtCurrentProcessId() (NtCurrentTeb()->ClientId.UniqueProcess)
calminstruction NtCurrentProcessId reg*
	call NtCurrentTeb,reg
	arrange reg,=mov reg,[reg+TEB.ClientId.UniqueProcess]
	assemble reg
end calminstruction

;#define NtCurrentThreadId() (NtCurrentTeb()->ClientId.UniqueThread)
calminstruction NtCurrentThreadId reg*
	call NtCurrentTeb,reg
	arrange reg,=mov reg,[reg+TEB.ClientId.UniqueThread]
	assemble reg
end calminstruction

;#define RtlProcessHeap()	(NtCurrentPeb()->ProcessHeap)
;#define RtlProcessHeap()	(HANDLE)(NtCurrentTeb()->ProcessEnvironmentBlock->ProcessHeap)
calminstruction RtlProcessHeap reg*
	local line
	call NtCurrentPeb,reg
	arrange line,=mov reg,[reg+PEB.ProcessHeap]
	assemble line
end calminstruction

;#define IsActiveConsoleSession() (USER_SHARED_DATA->ActiveConsoleId == NtCurrentPeb()->SessionId)






define RtlCreateHeap.Flags.HEAP_GENERATE_EXCEPTIONS
define RtlCreateHeap.Flags.HEAP_GROWABLE
define RtlCreateHeap.Flags.HEAP_NO_SERIALIZE

;NTSYSAPI PVOID RtlCreateHeap
;	[in]		ULONG			Flags
;	[in, optional]	PVOID			HeapBase
;	[in, optional]	SIZE_T			ReserveSize
;	[in, optional]	SIZE_T			CommitSize
;	[in, optional]	PVOID			Lock
;	[in, optional]	PRTL_HEAP_PARAMETERS	Parameters
calminstruction RtlCreateHeap Flags,HeapBase,ReserveSize,CommitSize,Lock,Parameters
end calminstruction
; returns _HEAP structre
; https://www.nirsoft.net/kernel_struct/vista/HEAP.html


define RtlAllocateHeap.Flags.HEAP_GENERATE_EXCEPTIONS
define RtlAllocateHeap.Flags.HEAP_NO_SERIALIZE
define RtlAllocateHeap.Flags.HEAP_ZERO_MEMORY

;NTSYSAPI PVOID RtlAllocateHeap
;	[in]		PVOID	HeapHandle
;	[in, optional]	ULONG	Flags
;	[in]		SIZE_T	Size
calminstruction RtlAllocateHeap HeapHandle,Flags,Size
end calminstruction


calminstruction RtlSizeHeap HeapHandle,Flags,BaseAddress
end calminstruction


calminstruction RtlReAllocateHeap HeapHandle,Flags,BaseAddress,Size
end calminstruction


;NTSYSAPI LOGICAL RtlFreeHeap
;	[in]		PVOID	HeapHandle
;	[in, optional]	ULONG	Flags
;	_Frees_ptr_opt_	PVOID	BaseAddress
calminstruction RtlFreeHeap HeapHandle,Flags,BaseAddress
	;HEAP_NO_SERIALIZE
end calminstruction


;NTSYSAPI PVOID RtlDestroyHeap
;	[in]		PVOID	HeapHandle
calminstruction RtlDestroyHeap HeapHandle
end calminstruction











