include 'dbg_dd64.inc'

use AMD64

format PE64 NX GUI 5.0
entry start

section '.data' data readable writeable

  _title db 'AVX-512 playground',0
  _error db 'AVX-512 instructions are not supported.',0


section '.text' code readable executable

    start:
	sub	rsp,28h

	xor	ecx,ecx
	lea	rdx,[_error]
	lea	r8,[_title]
	mov	r9d,10h
	call	[MessageBoxA]

	mov	ecx,1
	call	[ExitProcess]

section '.idata' import data readable writeable

    include 'imports.inc'
    imports KERNEL32.DLL, ExitProcess, USER32.DLL, MessageBoxA
