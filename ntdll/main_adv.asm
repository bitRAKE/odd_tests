
include 'syscall_adv.g', SYSCALL_BUILD equ "22621" ; change to your system build
include 'NtDef.g'


public mainCRTStartup as 'mainCRTStartup' ; linker expects this default name
:mainCRTStartup:
	virtual at rbp + 16
		.result		IO_STATUS_BLOCK
		.hStdOut	dq ?
		assert $-$$ < 33 ; shadow-space limit
	end virtual
	enter .frame, 0

	{data:8} .allocationSize dq 2048 ; LARGE_INTEGER

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

	NtCreateFile & .hStdOut, GENERIC_WRITE,\
		& .attributes, & .result, & .allocationSize,\
		FILE_ATTRIBUTE_NORMAL, FILE_SHARE_READ or FILE_SHARE_WRITE,\
		FILE_OPEN, FILE_NON_DIRECTORY_FILE, 0, 0

	{const:1} .message db "Hello, World!"
	{const:1} .message.bytes := $ - .message
	{const:8} .byte_offset dq 0

	NtWriteFile [.hStdOut], 0, 0, 0, & .result,\
		& .message, .message.bytes, & .byte_offset, 0
	NtClose [.hStdOut]
	NtTerminateProcess NtCurrentProcess, [.result.Status]
	jmp $


; configure linker from here
virtual as "response"
	db '/NOLOGO',10
;	db '/VERBOSE',10 ; use to debug process
	db '/NODEFAULTLIB',10
	db '/SUBSYSTEM:CONSOLE',10
end virtual
