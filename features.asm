;	fasm2.cmd features.asm
;	link @features.response features.obj

include 'console.g'

macro ← line& ; terse console output macro
	local str,chars
	match [ inner ],line
		define str inner
		define chars inner.chars
	else ; new data
		COFF.2.CONST str du line
		COFF.2.CONST chars := ($ - str) shr 1
	end match
	WriteConsoleW [hOutput], & str, chars, 0, 0
end macro

BLOCK COFF.64.DATA
	; standard handles:
	hInput		dq ?
	hOutput		dq ?
	hError		dq ?
END BLOCK

public mainCRTStartup as 'mainCRTStartup' ; linker expects this default entry point name
:mainCRTStartup:
	virtual at rbp+16
		.result		dd ?
		.dwMode		dd ?
		assert $-$$ < 33 ; shadowspace limitation
	end virtual
	enter .frame, 0
	mov [.result], 1 ; EXIT_FAILURE

	GetStdHandle STD_INPUT_HANDLE
	mov [hInput], rax
	GetStdHandle STD_OUTPUT_HANDLE
	mov [hOutput], rax
	GetStdHandle STD_ERROR_HANDLE
	mov [hError], rax

	GetConsoleMode [hOutput], & .dwMode
	mov edx, ENABLE_VIRTUAL_TERMINAL_PROCESSING
	or edx, [.dwMode]
	SetConsoleMode [hOutput], edx

; https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-isprocessorfeaturepresent
; %ProgramFiles(x86)%\Windows Kits\10\Include\10.0.26100.0\um\winnt.h
	iterate <INDEX, NAME>,\
		0,	PF_FLOATING_POINT_PRECISION_ERRATA,\
		1,	PF_FLOATING_POINT_EMULATED,\
		2,	PF_COMPARE_EXCHANGE_DOUBLE,\
		3,	PF_MMX_INSTRUCTIONS_AVAILABLE,\
\;		4,	PF_PPC_MOVEMEM_64BIT_OK,\
\;		5,	PF_ALPHA_BYTE_INSTRUCTIONS,\
		6,	PF_XMMI_INSTRUCTIONS_AVAILABLE,\
		7,	PF_3DNOW_INSTRUCTIONS_AVAILABLE,\
		8,	PF_RDTSC_INSTRUCTION_AVAILABLE,\
		9,	PF_PAE_ENABLED,\
		10,	PF_XMMI64_INSTRUCTIONS_AVAILABLE,\
		11,	PF_SSE_DAZ_MODE_AVAILABLE,\
		12,	PF_NX_ENABLED,\
		13,	PF_SSE3_INSTRUCTIONS_AVAILABLE,\
		14,	PF_COMPARE_EXCHANGE128,\
		15,	PF_COMPARE64_EXCHANGE128,\
		16,	PF_CHANNELS_ENABLED,\
		17,	PF_XSAVE_ENABLED,\
\;		18,	PF_ARM_VFP_32_REGISTERS_AVAILABLE,\
\;		19,	PF_ARM_NEON_INSTRUCTIONS_AVAILABLE,\
		20,	PF_SECOND_LEVEL_ADDRESS_TRANSLATION,\
		21,	PF_VIRT_FIRMWARE_ENABLED,\
		22,	PF_RDWRFSGSBASE_AVAILABLE,\
		23,	PF_FASTFAIL_AVAILABLE,\
\;		24,	PF_ARM_DIVIDE_INSTRUCTION_AVAILABLE,\
\;		25,	PF_ARM_64BIT_LOADSTORE_ATOMIC,\
\;		26,	PF_ARM_EXTERNAL_CACHE_AVAILABLE,\
\;		27,	PF_ARM_FMAC_INSTRUCTIONS_AVAILABLE,\
		28,	PF_RDRAND_INSTRUCTION_AVAILABLE,\
\;		29,	PF_ARM_V8_INSTRUCTIONS_AVAILABLE,\
\;		30,	PF_ARM_V8_CRYPTO_INSTRUCTIONS_AVAILABLE,\
\;		31,	PF_ARM_V8_CRC32_INSTRUCTIONS_AVAILABLE,\
		32,	PF_RDTSCP_INSTRUCTION_AVAILABLE,\
		33,	PF_RDPID_INSTRUCTION_AVAILABLE,\
\;		34,	PF_ARM_V81_ATOMIC_INSTRUCTIONS_AVAILABLE,\
		35,	PF_MONITORX_INSTRUCTION_AVAILABLE,\
		36,	PF_SSSE3_INSTRUCTIONS_AVAILABLE,\
		37,	PF_SSE4_1_INSTRUCTIONS_AVAILABLE,\
		38,	PF_SSE4_2_INSTRUCTIONS_AVAILABLE,\
		39,	PF_AVX_INSTRUCTIONS_AVAILABLE,\
		40,	PF_AVX2_INSTRUCTIONS_AVAILABLE,\
		41,	PF_AVX512F_INSTRUCTIONS_AVAILABLE,\
		42,	PF_ERMS_AVAILABLE,\
\;		43,	PF_ARM_V82_DP_INSTRUCTIONS_AVAILABLE,\
\;		44,	PF_ARM_V83_JSCVT_INSTRUCTIONS_AVAILABLE,\
\;		45,	PF_ARM_V83_LRCPC_INSTRUCTIONS_AVAILABLE,\
\;		46,	PF_ARM_SVE_INSTRUCTIONS_AVAILABLE,\
\;		47,	PF_ARM_SVE2_INSTRUCTIONS_AVAILABLE,\
\;		48,	PF_ARM_SVE2_1_INSTRUCTIONS_AVAILABLE,\
\;		49,	PF_ARM_SVE_AES_INSTRUCTIONS_AVAILABLE,\
\;		50,	PF_ARM_SVE_PMULL128_INSTRUCTIONS_AVAILABLE,\
\;		51,	PF_ARM_SVE_BITPERM_INSTRUCTIONS_AVAILABLE,\
\;		52,	PF_ARM_SVE_BF16_INSTRUCTIONS_AVAILABLE,\
\;		53,	PF_ARM_SVE_EBF16_INSTRUCTIONS_AVAILABLE,\
\;		54,	PF_ARM_SVE_B16B16_INSTRUCTIONS_AVAILABLE,\
\;		55,	PF_ARM_SVE_SHA3_INSTRUCTIONS_AVAILABLE,\
\;		56,	PF_ARM_SVE_SM4_INSTRUCTIONS_AVAILABLE,\
\;		57,	PF_ARM_SVE_I8MM_INSTRUCTIONS_AVAILABLE,\
\;		58,	PF_ARM_SVE_F32MM_INSTRUCTIONS_AVAILABLE,\
\;		59,	PF_ARM_SVE_F64MM_INSTRUCTIONS_AVAILABLE,\
		60,	PF_BMI2_INSTRUCTIONS_AVAILABLE,\
		61,	(undocumented) 61,\
		62,	(undocumented) 62,\
		63,	(undocumented) 63

		IsProcessorFeaturePresent INDEX
		test eax, eax			; BOOL
		jnz .%				; Y: feature present
		← [DarkRed]
		jmp @F
	.%:
		← [Green]
	@@:	← `NAME,10
	end iterate
	← 27,'[m' ; reset text
	mov [.result], 0 ; EXIT_SUCCESS
.no_session:
	SetConsoleMode [hOutput], [.dwMode]
	ExitProcess [.result]
	jmp $

COFF.2.CONST Green du 27,'[32m'
COFF.2.CONST Green.chars := ($ - Green) shr 1

COFF.2.CONST DarkRed du 27,'[38;5;88m'
COFF.2.CONST DarkRed.chars := ($ - DarkRed) shr 1

;-------------------------------------------------------------------------------

virtual as "response" ; configure linker from here:
	db '/NOLOGO',10
;	db '/VERBOSE',10,'/TIME+',10	; use to debug process

; Create unique binary using image version and checksum:
	repeat 1,T:__TIME__ shr 16,t:__TIME__ and 0xFFFF
		db '/VERSION:',`T,'.',`t,10
	end repeat
	db '/RELEASE',10		; set program checksum in header

	db '/FIXED',10			; no relocation information
	db '/IGNORE:4281',10		; ASLR doesn't happen for /FIXED!
	db '/BASE:0x7FFF0000',10	; above KUSER_SHARED_DATA
	db '/SUBSYSTEM:CONSOLE,6.02',10	; Win8+
	db '/NODEFAULTLIB',10		; all dependencies explicit, below

	db 'kernel32.lib',10
end virtual
