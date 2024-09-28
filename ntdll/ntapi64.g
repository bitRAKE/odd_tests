
; work in progress ...
; References:
;	\Windows Kits\10\Include\10.0.22621.0
;		\um\nt*
;		\km\nt*
;	https://github.com/MeeSong/Reverse-Engineering/blob/master/Include/ntbase.h
;	https://github.com/0mWindyBug/MinifilterHook/blob/dd2f68a28036b6c3c9949732fdb837aee6e5e8e4/WdfltHook/WdfltHook/ntdefs.h#L268
;	https://github.com/AlexanderBagel/ProcessMemoryMap/blob/master/doc/ntdll.h





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










; https://www.vergiliusproject.com/kernels/x64/windows-11/23h2/_PEB64

struct GUID
	Data1	dd ?
	Data2	dw ?
	Data3	dw ?
	Data4	rb 8
ends

struct STRING64			; offsets
	Length		dw ?	; 0x00
	MaximumLength	dw ?	; 0x02
		__0	dd ?
	Buffer		dq ?	; 0x08
ends
assert 0x10 = sizeof STRING64

struct LIST_ENTRY64
	Flink	dq ?
	Blink	dq ?
ends

struct CLIENT_ID64
	UniqueProcess	dq ?
	UniqueThread	dq ?
ends

struct NT_TIB64
	ExceptionList		dq ?
	StackBase		dq ?
	StackLimit		dq ?
	SubSystemTib		dq ?
	union
		FiberData	dq ?
		Version		dd ?
	ends
	ArbitraryUserPointer	dq ?
	Self			dq ?
ends
assert 0x38 = sizeof NT_TIB64

struct ACTIVATION_CONTEXT_STACK64
	ActiveFrame			dq ?	; 0x00
	FrameListCache		LIST_ENTRY64	; 0x08
	Flags				dd ?	; 0x18
	NextCookieSequenceNumber	dd ?	; 0x1C
	StackId				dd ?	; 0x20
				__0	dd ?
ends
assert 0x28 = sizeof ACTIVATION_CONTEXT_STACK64

struct GDI_TEB_BATCH64
	HasRenderingCommand	dd ?	; 0x8000_0000
			__0	dd ?
	HDC			dq ?
	Buffer			rd 310
ends
assert 0x4E8 = sizeof GDI_TEB_BATCH64

struct PROCESSOR_NUMBER
	Group		dw ?
	Number		db ?
	Reserved	db ?
ends

struct PEB64
	InheritedAddressSpace		db ?	; 0x0
	ReadImageFileExecOptions	db ?	; 0x1
	BeingDebugged			db ?	; 0x2
	BitField			db ?	; 0x3
;		ImageUsesLargePages		:= 0x01
;		IsProtectedProcess		:= 0x02
;		IsImageDynamicallyRelocated	:= 0x04
;		SkipPatchingUser32Forwarders	:= 0x08
;		IsPackagedProcess		:= 0x10
;		IsAppContainer			:= 0x20
;		IsProtectedProcessLight		:= 0x40
;		IsLongPathAwareProcess		:= 0x80
__0	dd ?
	Mutant				dq ?	; 0x8
	ImageBaseAddress		dq ?	; 0x10
	Ldr				dq ?	; 0x18
	ProcessParameters		dq ?	; 0x20
	SubSystemData			dq ?	; 0x28
	ProcessHeap			dq ?	; 0x30
	FastPebLock			dq ?	; 0x38
	AtlThunkSListPtr		dq ?	; 0x40
	IFEOKey				dq ?	; 0x48
	CrossProcessFlags		dd ?	; 0x50
;		ProcessInJob			:= 0x0000_0001
;		ProcessInitializing		:= 0x0000_0002
;		ProcessUsingVEH			:= 0x0000_0004
;		ProcessUsingVCH			:= 0x0000_0008
;		ProcessUsingFTH			:= 0x0000_0010
;		ProcessPreviouslyThrottled	:= 0x0000_0020
;		ProcessCurrentlyThrottled	:= 0x0000_0040
;		ProcessImagesHotPatched		:= 0x0000_0080
__1	dd ?
	union
		KernelCallbackTable	dq ?	; 0x58
		UserSharedInfoPtr	dq ?	; 0x58
	ends
	SystemReserved			dd ?	; 0x60
	AtlThunkSListPtr32		dd ?	; 0x64
	ApiSetMap			dq ?	; 0x68
	TlsExpansionCounter		dd ?	; 0x70
__2	dd ?
	TlsBitmap			dq ?	; 0x78
	TlsBitmapBits			dd ?,?	; 0x80
	ReadOnlySharedMemoryBase	dq ?	; 0x88
	SharedData			dq ?	; 0x90
	ReadOnlyStaticServerData	dq ?	; 0x98
	AnsiCodePageData		dq ?	; 0xa0
	OemCodePageData			dq ?	; 0xa8
	UnicodeCaseTableData		dq ?	; 0xb0
	NumberOfProcessors		dd ?	; 0xb8
	NtGlobalFlag			dd ?	; 0xbc
	CriticalSectionTimeout		dq ?	; 0xc0
	HeapSegmentReserve		dq ?	; 0xc8
	HeapSegmentCommit		dq ?	; 0xd0
	HeapDeCommitTotalFreeThreshold	dq ?	; 0xd8
	HeapDeCommitFreeBlockThreshold	dq ?	; 0xe0
	NumberOfHeaps			dd ?	; 0xe8
	MaximumNumberOfHeaps		dd ?	; 0xec
	ProcessHeaps			dq ?	; 0xf0
	GdiSharedHandleTable		dq ?	; 0xf8
	ProcessStarterHelper		dq ?	; 0x100
	GdiDCAttributeList		dd ?	; 0x108
__3	dd ?
	LoaderLock			dq ?	; 0x110
	OSMajorVersion			dd ?	; 0x118
	OSMinorVersion			dd ?	; 0x11c
	OSBuildNumber			dw ?	; 0x120
	OSCSDVersion			dw ?	; 0x122
	OSPlatformId			dd ?	; 0x124
	ImageSubsystem			dd ?	; 0x128
	ImageSubsystemMajorVersion	dd ?	; 0x12c
	ImageSubsystemMinorVersion	dd ?	; 0x130
__4	dd ?
	ActiveProcessAffinityMask	dq ?	; 0x138
	GdiHandleBuffer			rd 60	; 0x140
	PostProcessInitRoutine		dq ?	; 0x230
	TlsExpansionBitmap		dq ?	; 0x238
	TlsExpansionBitmapBits		rd 32	; 0x240
	SessionId			dd ?	; 0x2c0
__5	dd ?
	AppCompatFlags			dq ?	; 0x2c8
	AppCompatFlagsUser		dq ?	; 0x2d0
	pShimData			dq ?	; 0x2d8
	AppCompatInfo			dq ?	; 0x2e0
	CSDVersion STRING64			; 0x2e8
	ActivationContextData		dq ?	; 0x2f8
	ProcessAssemblyStorageMap	dq ?	; 0x300
	SystemDefaultActivationContextData dq ?	; 0x308
	SystemAssemblyStorageMap	dq ?	; 0x310
	MinimumStackCommit		dq ?	; 0x318
	SparePointers			dq ?,?	; 0x320
	PatchLoaderData			dq ?	; 0x330
	ChpeV2ProcessInfo		dq ?	; 0x338
	AppModelFeatureState		dd ?	; 0x340
	SpareUlongs			dd ?,?	; 0x344
	ActiveCodePage			dd ?	; 0x34c
	OemCodePage			dd ?	; 0x34e
	UseCaseMapping			dd ?	; 0x350
	UnusedNlsField			dd ?	; 0x352
	WerRegistrationData		dq ?	; 0x358
	WerShipAssertPtr		dq ?	; 0x360
	EcCodeBitMap			dq ?	; 0x368
	pImageHeaderHash		dq ?	; 0x370
	TracingFlags			dd ?	; 0x378
;		HeapTracingEnabled	:= 0x0000_0001
;		CritSecTracingEnabled	:= 0x0000_0002
;		LibLoaderTracingEnabled	:= 0x0000_0004
__6	dd ?
	CsrServerReadOnlySharedMemoryBase dq ?	; 0x380
	TppWorkerpListLock		dq ?	; 0x388
	TppWorkerpList LIST_ENTRY64		; 0x390
	WaitOnAddressHashTable		rq 128	; 0x3A0
	TelemetryCoverageHeader		dq ?	; 0x7a0
	CloudFileFlags			dd ?	; 0x7a8
	CloudFileDiagFlags		dd ?	; 0x7ac
	PlaceholderCompatibilityMode	db ?	; 0x7b0
__7	rb 7
	LeapSecondData			dq ?	; 0x7b8
	LeapSecondFlags			dd ?	; 0x7c0
;		SixtySecondEnabled	:= 0x0000_0001
	NtGlobalFlag2			dd ?	; 0x7c4
	ExtendedFeatureDisableMask	dq ?	; 0x7c8
ends
assert 0x7D0 = sizeof PEB64


struct TEB64
	NtTib			NT_TIB64	; 0x0
	EnvironmentPointer		dq ?	; 0x38
	ClientId		CLIENT_ID64	; 0x40
	ActiveRpcHandle			dq ?	; 0x50
	ThreadLocalStoragePointer	dq ?	; 0x58
	ProcessEnvironmentBlock		dq ?	; 0x60
	LastErrorValue			dd ?	; 0x68
	CountOfOwnedCriticalSections	dd ?	; 0x6c
	CsrClientThread			dq ?	; 0x70
	Win32ThreadInfo			dq ?	; 0x78
	User32Reserved			rd 26	; 0x80
	UserReserved			rd 5	; 0xE8
	WOW32Reserved			dq ?	; 0x100
	CurrentLocale			dd ?	; 0x108
	FpSoftwareStatusRegister	dd ?	; 0x10c
	ReservedForDebuggerInstrumentation rq 16	; 0x110
	SystemReserved1			rq 30	; 0x190
	PlaceholderCompatibilityMode	db ?	; 0x280
	PlaceholderHydrationAlwaysExplicit db ?	; 0x281
	PlaceholderReserved		rb 10	; 0x282
	ProxiedProcessId		dd ?	; 0x28c
	ActivationStack		ACTIVATION_CONTEXT_STACK64	; 0x290
	WorkingOnBehalfTicket		rb 8	; 0x2b8
	ExceptionCode			dd ?	; 0x2c0
__0 rb 4
	ActivationContextStackPointer	dq ?	; 0x2c8
	InstrumentationCallbackSp	dq ?	; 0x2d0
	InstrumentationCallbackPreviousPc dq ?	; 0x2d8
	InstrumentationCallbackPreviousSp dq ?	; 0x2e0
	TxFsContext			dd ?	; 0x2e8
	InstrumentationCallbackDisabled	db ?	; 0x2ec
	UnalignedLoadStoreExceptions	db ?	; 0x2ed
__1 rb 2
	GdiTebBatch		GDI_TEB_BATCH64	; 0x2f0
	RealClientId		CLIENT_ID64	; 0x7d8
	GdiCachedProcessHandle		dq ?	; 0x7e8
	GdiClientPID			dd ?	; 0x7f0
	GdiClientTID			dd ?	; 0x7f4
	GdiThreadLocalInfo		dq ?	; 0x7f8
	Win32ClientInfo			rq 62	; 0x800
	glDispatchTable			rq 233	; 0x9f0
	glReserved1			rq 30	; 0x1138
	glSectionInfo			dq ?	; 0x1228
	glSection			dq ?	; 0x1230
	glTable				dq ?	; 0x1238
	glCurrentRC			dq ?	; 0x1240
	glContext			dq ?	; 0x1248
	LastStatusValue			dd ?	; 0x1250
__2 rb 4
	StaticUnicodeString STRING64		; 0x1258
	StaticUnicodeBuffer		rw 261	; 0x1268
__3 rb 6
	DeallocationStack		dq ?	; 0x1478
	TlsSlots			rq 64	; 0x1480
	TlsLinks		LIST_ENTRY64	; 0x1680
	Vdm				dq ?	; 0x1690
	ReservedForNtRpc		dq ?	; 0x1698
	DbgSsReserved			rq 2	; 0x16a0
	HardErrorMode			dd ?	; 0x16b0
__4 rb 4
	Instrumentation			rq 11	; 0x16b8
	ActivityId			rb 16	; 0x1710 GUID
	SubProcessTag			dq ?	; 0x1720
	PerflibData			dq ?	; 0x1728
	EtwTraceData			dq ?	; 0x1730
	WinSockData			dq ?	; 0x1738
	GdiBatchCount			dd ?	; 0x1740
	union
		CurrentIdealProcessor	dd ?	; 0x1744; PROCESSOR_NUMBER
		IdealProcessorValue	dd ?	; 0x1744
;		ReservedPad0	db ?,?,? ; 0x1744
;		IdealProcessor	db ?	; 0x1747
	ends
	GuaranteedStackBytes		dd ?	; 0x1748
__5 rb 4
	ReservedForPerf			dq ?	; 0x1750
	ReservedForOle			dq ?	; 0x1758
	WaitingOnLoaderLock		dd ?	; 0x1760
__6 rb 4
	SavedPriorityState		dq ?	; 0x1768
	ReservedForCodeCoverage		dq ?	; 0x1770
	ThreadPoolData			dq ?	; 0x1778
	TlsExpansionSlots		dq ?	; 0x1780
	ChpeV2CpuAreaInfo		dq ?	; 0x1788
	Unused				dq ?	; 0x1790
	MuiGeneration			dd ?	; 0x1798
	IsImpersonating			dd ?	; 0x179c
	NlsCache			dq ?	; 0x17a0
	pShimData			dq ?	; 0x17a8
	HeapData			dd ?	; 0x17b0
__7 rb 4
	CurrentTransactionHandle	dq ?	; 0x17b8
	ActiveFrame			dq ?	; 0x17c0
	FlsData				dq ?	; 0x17c8
	PreferredLanguages		dq ?	; 0x17d0
	UserPrefLanguages		dq ?	; 0x17d8
	MergedPrefLanguages		dq ?	; 0x17e0
	MuiImpersonation		dd ?	; 0x17e8
	CrossTebFlags			dw ?	; 0x17ec
	SameTebFlags			dw ?	; 0x17ee
;		SafeThunkCall		:= 0x0001
;		InDebugPrint		:= 0x0002
;		HasFiberData		:= 0x0004
;		SkipThreadAttach	:= 0x0008
;		WerInShipAssertCode	:= 0x0010
;		RanProcessInit		:= 0x0020
;		ClonedThread		:= 0x0040
;		SuppressDebugMsg	:= 0x0080
;		DisableUserStackWalk	:= 0x0100
;		RtlExceptionAttached	:= 0x0200
;		InitialThread		:= 0x0400
;		SessionAware		:= 0x0800
;		LoadOwner		:= 0x1000
;		LoaderWorker		:= 0x2000
;		SkipLoaderInit		:= 0x4000
;		SkipFileAPIBrokering	:= 0x8000
	TxnScopeEnterCallback		dq ?	; 0x17f0
	TxnScopeExitCallback		dq ?	; 0x17f8
	TxnScopeContext			dq ?	; 0x1800
	LockCount			dd ?	; 0x1808
	WowTebOffset			dd ?	; 0x180c
	ResourceRetValue		dq ?	; 0x1810
	ReservedForWdf			dq ?	; 0x1818
	ReservedForCrt			dq ?	; 0x1820
	EffectiveContainerId		rb 16	; 0x1828 GUID
	LastSleepCounter		dq ?	; 0x1838
	SpinCallCount			dd ?	; 0x1840
__8 rb 4
	ExtendedFeatureDisableMask	dq ?	; 0x1848
ends
assert 0x1850 = sizeof TEB64
