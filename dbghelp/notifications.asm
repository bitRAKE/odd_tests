
; Advanced Demonstration of DbgHelp Notification Handling:
; (expanding on https://learn.microsoft.com/en-us/windows/win32/debug/getting-notifications)
;
; Setup symbol search path prior to execution:
; https://learn.microsoft.com/en-us/windows/win32/debug/symbol-paths
;	Search order:
;		_NT_SYMBOL_PATH
;		_NT_ALT_SYMBOL_PATH
;		module directory
; Example:
;	set _NT_SYMBOL_PATH=cache*y:\Symbols;srv*https://msdl.microsoft.com/download/symbols
;
;
; Can pass several modules on the commandline ...
;	notifications.exe dbghelp.dll symsrv.dll

include 'console.g'
include 'debug.g'	;✓ error message helper
include 'dbghelp.g'


; BOOL SymbolRegisteredCallbackW64(HANDLE hProcess, ULONG ActionCode, PVOID CallbackData, PVOID UserContext);
:SymbolRegisteredCallbackW64:
	iterate action, CBA_EVENT
		cmp edx, action
		jz .action
	end iterate
	xor eax, eax ; FALSE, action not handled
	retn

.CBA_EVENT: ;*IMAGEHLP_CBA_EVENT ; W same
	virtual at rbp - .local
		.buffer rw 1280
		.local := $-$$
	end virtual
	enter .frame + .local, 0

	; Try to display all the event structure detail:
	; (Note: desc contains a newline; object=0 for events?)

	mov eax, sevMax
	mov r10d, [r8 + IMAGEHLP_CBA_EVENT.severity]
	cmp r10d, eax
	cmovnc r10d, eax ; clamp to range [0-sevMax]
	mov r11, r8
	wsprintfW & .buffer, <W 'CBA_EVENT: %s [%d] : %s'>,\
		[.Severity_Table + r10*8],\
		[r11 + IMAGEHLP_CBA_EVENT.code],\
		[r11 + IMAGEHLP_CBA_EVENT.desc]
	xchg r8d, eax ; characters
	WriteConsoleW [g_hOutput], & .buffer, r8, 0, 0
	mov eax, TRUE ; action handled
	leave
	retn

	iterate severity, sevInfo,sevProblem,sevAttn,sevFatal,UNKNOWN;sevMax
{const:2}	.sev.% du `severity,0
		if %=%%
			assert %% = 1+sevMax ; sanity check, new data?
{const:8}		.Severity_Table:
			repeat %%
{const:8}			dq .sev.%
			end repeat
		end if
	end iterate


{data:8} g_hOutput dq -1

public mainCRTStartup as 'mainCRTStartup' ; linker expects this default name
:mainCRTStartup:
	virtual at rbp - .local
		.argv		dq ?
		.argn		dd ?
			align.assume rbp,16
			align 16
		.local := $-$$
				rq 2
		.result		dd ?
		.last_error	dd ?
		.lpBuffer	dq ?
		assert $-.result < 33 ; shadowspace limitation
	end virtual
	enter .frame + .local, 0
	mov [.result], 1 ; EXIT_FAILURE

	GetStdHandle STD_OUTPUT_HANDLE
	mov [g_hOutput], rax
	inc rax
	jz .fatal

	GetCommandLineW
	test rax, rax
	jz .fatal
	xchg rcx, rax
	CommandLineToArgvW rcx, & .argn
	test rax, rax
	jz .fatal
	mov [.argv], rax
	xchg rsi, rax
	lodsq ; skip program name
	test rax, rax
	jz .fatal

	SymSetOptions SYMOPT_DEBUG ; DWORD (prior?) Options

	.hProcess := 123 ; unique id to reference interaction with DbgHelp

✓	SymInitializeW .hProcess, NULL, FALSE
	test eax, eax ; BOOL
	jz .fail_GetLastError

✓	SymRegisterCallbackW64 .hProcess, & SymbolRegisteredCallbackW64, NULL
	test eax, eax ; BOOL
	jz .fail_GetLastError

.more_modules:	; load all modules into the session
	lodsq
✓	SymLoadModuleExW .hProcess,\
		NULL,\		; no open file handle to image
		rax,\		;name of image to load
		rdx,\		; no module name - dbghelp will get it
		rdx,\		; no base address - dbghelp will get it
		edx,\		; no module size - dbghelp will get it
		rdx,\		; no special MODLOAD_DATA structure
		edx		; flags
	test eax, eax ; BOOL
	jz .fail_GetLastError
	cmp qword [rsi], 0
	jnz .more_modules

	mov [.result], 0 ; EXIT_SUCCESS
.cleanup:
✓	SymCleanup .hProcess
	test eax, eax ; BOOL
	jz .fail_GetLastError

	LocalFree [.argv]
.fatal:
	ExitProcess [.result]
	jmp $


.fail_GetLastError:
	mov [.lpBuffer], r11

	GetLastError ; first, preserve last error value
	mov [.last_error], eax

	; next, display message RDX
	mov rdx, [.lpBuffer]
	movzx r8, word [rdx-2] ; characters
	WriteConsoleW [g_hOutput], rdx, r8, 0, 0

	FormatMessageW FORMAT_MESSAGE_ALLOCATE_BUFFER\
		\; always use these two together
		or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,\
		0, [.last_error], 0, & .lpBuffer, 0, 0
	xchg r8d, eax ; characters
	WriteConsoleW [g_hOutput], [.lpBuffer], r8, 0, 0
	LocalFree [.lpBuffer]

; Assume SymCleanup cannot fail with ERROR_SUCCESS, otherwise infinite loop.
; Yet, everything else can do so.

	cmp [.last_error], 0 ; ERROR_SUCCESS
	jz .cleanup

	jmp .fatal



virtual as "response" ; configure linker from here:
	db '/NOLOGO',10
;	db '/VERBOSE',10 ; use to debug process
	db '/NODEFAULTLIB',10
	db '/BASE:0x10000',10
	db '/DYNAMICBASE:NO',10
	db '/IGNORE:4281',10 ; bogus warning to scare people away
	db '/SUBSYSTEM:CONSOLE,6.02',10
	db 'dbghelp.lib',10
	db 'kernel32.lib',10
	db 'user32.lib',10	; wsprintfW
	db 'shell32.lib',10	; CommandLineToArgvW
end virtual
