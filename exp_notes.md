

If using table based exception handling MS states: Table-based exception handling requires a table entry for all functions that allocate stack space or call another function (for example, nonleaf functions).




https://board.flatassembler.net/topic.php?p=111373

struct RUNTIME_FUNCTION ; RVA offsets (__ImageBase relative)
	begin	dd ?
	end	dd ?
	unwind	dd ?
ends

struct UNWIND_INFO
	vflags	db ?
	psize	db ?	; length of prolog code bytes
	codes	db ?	; unwind code slots used
	freg	db ?	; frame register and scaled (x16) offset from RSP [0,240]
; unwind codes ...
ends

UNW_FLAG_NHANDLER	:=0 ; any handler
UNW_FLAG_EHANDLER	:=1 ; filter handler
UNW_FLAG_UHANDLER	:=2 ; unwind handler

UNW_FLAG_NO_EPILOGUE	:=0x80000000 ; Software only flag

UNWIND_CHAIN_LIMIT	:= 32

struct DISPATCHER_CONTEXT
    DWORD64 ControlPc;
    DWORD64 ImageBase;
    PRUNTIME_FUNCTION FunctionEntry;
    DWORD64 EstablisherFrame;
    DWORD64 TargetIp;
    PCONTEXT ContextRecord;
    PEXCEPTION_ROUTINE LanguageHandler;
    PVOID HandlerData;
    struct _UNWIND_HISTORY_TABLE *HistoryTable;
    DWORD ScopeIndex;
    DWORD Fill0;
ends




