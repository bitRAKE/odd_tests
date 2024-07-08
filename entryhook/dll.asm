include 'windows.g'
;	fasm2 dll.asm
;	link @dll.response dll.obj
;-------------------------------------------------------------------------------
; 🚨 Want to hook the application entry point from DllMain with just a pointer swap?
; 🚨 You can replace the RtlUserThreadStart pointer in the CONTEXT on the stack.
; https://x.com/mrexodia/status/1809936086400938187

{bss:8} original_RtlUserThreadStart dq ?

 ; void (PTHREAD_START_ROUTINE fpTransferAddress, PVOID pContext)
:hook_RtlUserThreadStart:
	push rdx rcx
	enter .frame, 0
	MessageBoxA 0, A "!Entry point hijacked", A "Success", MB_SYSTEMMODAL or MB_RTLREADING
	leave
	pop rcx rdx ; fpTransferAddress, pContext
	jmp [original_RtlUserThreadStart]


; BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpReserved);
public _DllMainCRTStartup as '_DllMainCRTStartup' ; linker expects this default name
:_DllMainCRTStartup:
	cmp edx, DLL_PROCESS_ATTACH
	jnz @1F

	enter .frame, 0
	GetModuleHandleA A "ntdll.dll"
	xchg rcx, rax
	GetProcAddress rcx, A "RtlUserThreadStart"
	mov [original_RtlUserThreadStart], rax

	GetModuleHandleA 0 ; process __ImageBase
	mov ecx, [rax + IMAGE_DOS_HEADER.e_lfanew]
	mov ecx, [rax + rcx + IMAGE_NT_HEADERS64.OptionalHeader.AddressOfEntryPoint]
	add rax, rcx

	mov rdx, [original_RtlUserThreadStart]
	mov ecx, 0x180 ; search range
@@:	cmp [rbp + rcx*8 + CONTEXT.Rip], rdx ; original_RtlUserThreadStart
	jnz @9F
	cmp [rbp + rcx*8 + CONTEXT.Rcx], rax ; entryPoint
@9:	loopnz @B
	jnz @2F ; Y: not found, skip hook

	lea rax, [hook_RtlUserThreadStart]
	mov [rbp + (rcx+1)*8 + CONTEXT.Rip], rax
@2:	leave
@1:	mov eax, 1
	retn



public _Add as '?Add@@YAHHH@Z' ; decorated name for linker
:_Add:	; __declspec(dllexport) int Add(int a, int b) {
	lea eax, [rcx + rdx]
	retn



public _Sub as '?Subtract@@YAHHH@Z' ; decorated name for linker
_Sub:	; __declspec(dllexport) int Subtract(int a, int b) {
	xchg eax, ecx
	sub eax, edx
	retn



; configure linker from here
virtual as "response"
	db '/NOLOGO',10
;	db '/VERBOSE',10 ; use to debug process
	db '/NODEFAULTLIB',10
	db "/DLL",10
	db '/SUBSYSTEM:WINDOWS,6.02',10
	db "/EXPORT:Add=?Add@@YAHHH@Z",10
	db "/EXPORT:Subtract=?Subtract@@YAHHH@Z",10
	db 'kernel32.lib',10
	db 'user32.lib',10
end virtual

;-------------------------------------------------------------------------------

struct IMAGE_DOS_HEADER
	e_magic		dw ?
	e_cblp		dw ?
	e_cp		dw ?
	e_crlc		dw ?
	e_cparhdr	dw ?
	e_minalloc	dw ?
	e_maxalloc	dw ?
	e_ss		dw ?
	e_sp		dw ?
	e_csum		dw ?
	e_ip		dw ?
	e_cs		dw ?
	e_lfarlc	dw ?
	e_ovno		dw ?
	e_res		rw 4
	e_oemid		dw ?
	e_oeminfo	dw ?
	e_res2		rw 10
	e_lfanew	dd ?
ends

struct IMAGE_NT_HEADERS64
	Signature	dd ?
	FileHeader	IMAGE_FILE_HEADER
	OptionalHeader	IMAGE_OPTIONAL_HEADER64
ends

struct IMAGE_FILE_HEADER
	Machine			dw ?
	NumberOfSections	dw ?
	TimeDateStamp		dd ?
	PointerToSymbolTable	dd ?
	NumberOfSymbols		dd ?
	SizeOfOptionalHeader	dw ?
	Characteristics		dw ?
ends

struct IMAGE_OPTIONAL_HEADER64
	Magic				dw ?
	MajorLinkerVersion		db ?
	MinorLinkerVersion		db ?
	SizeOfCode			dd ?
	SizeOfInitializedData		dd ?
	SizeOfUninitializedData		dd ?
	AddressOfEntryPoint		dd ?
	BaseOfCode			dd ?
	ImageBase			dq ?
	SectionAlignment		dd ?
	FileAlignment			dd ?
	MajorOperatingSystemVersion	dw ?
	MinorOperatingSystemVersion	dw ?
	MajorImageVersion		dw ?
	MinorImageVersion		dw ?
	MajorSubsystemVersion		dw ?
	MinorSubsystemVersion		dw ?
	Win32VersionValue		dd ?
	SizeOfImage			dd ?
	SizeOfHeaders			dd ?
	CheckSum			dd ?
	Subsystem			dw ?
	DllCharacteristics		dw ?
	SizeOfStackReserve		dq ?
	SizeOfStackCommit		dq ?
	SizeOfHeapReserve		dq ?
	SizeOfHeapCommit		dq ?
	LoaderFlags			dd ?
	NumberOfRvaAndSizes		dd ?
	DataDirectory			IMAGE_DATA_DIRECTORY
	repeat IMAGE_NUMBEROF_DIRECTORY_ENTRIES-1
		DataDirectory.% IMAGE_DATA_DIRECTORY
	end repeat
ends

struct IMAGE_DATA_DIRECTORY
	VirtualAddress	dd ?
	Size		dd ?
ends

IMAGE_NUMBEROF_DIRECTORY_ENTRIES := 16



; DECLSPEC_ALIGN(16)
struct XMM_SAVE_AREA32
	ControlWord	dw ?
	StatusWord	dw ?
	TagWord		db ?
	Reserved1	db ?
	ErrorOpcode	dw ?
	ErrorOffset	dd ?
	ErrorSelector	dw ?
	Reserved2	dw ?
	DataOffset	dd ?
	DataSelector	dw ?
	Reserved3	dw ?
	MxCsr		dd ?
	MxCsr_Mask	dd ?
	FloatRegisters	rdq 8
	XmmRegisters	rdq 16
	Reserved4	rb 96
ends

; DECLSPEC_ALIGN(16) DECLSPEC_NOINITALL
struct CONTEXT
	; Register parameter home addresses.
	; N.B. These fields are for convience - they could be used to extend the context record in the future.
	P1Home		dq ?
	P2Home		dq ?
	P3Home		dq ?
	P4Home		dq ?
	P5Home		dq ?
	P6Home		dq ?

	; Control flags.
	ContextFlags	dd ?
	MxCsr		dd ?

	; Segment Registers and processor flags.
	SegCs		dw ?
	SegDs		dw ?
	SegEs		dw ?
	SegFs		dw ?
	SegGs		dw ?
	SegSs		dw ?
	EFlags		dd ?

	; Debug registers
	Dr0		dq ?
	Dr1		dq ?
	Dr2		dq ?
	Dr3		dq ?
	Dr6		dq ?
	Dr7		dq ?

	; Integer registers.
	Rax		dq ?
	Rcx		dq ?
	Rdx		dq ?
	Rbx		dq ?
	Rsp		dq ?
	Rbp		dq ?
	Rsi		dq ?
	Rdi		dq ?
	R8		dq ?
	R9		dq ?
	R10		dq ?
	R11		dq ?
	R12		dq ?
	R13		dq ?
	R14		dq ?
	R15		dq ?

	; Program counter.
	Rip		dq ?

	; Floating point state.
	FltSave XMM_SAVE_AREA32

	; Vector registers.
	VectorRegister	rdq 26
	VectorControl	dq ?

	; Special debug control registers.
	DebugControl		dq ?
	LastBranchToRip		dq ?
	LastBranchFromRip	dq ?
	LastExceptionToRip	dq ?
	LastExceptionFromRip	dq ?
ends









