; Simple SYSCALL wrapper to abstract function numbers.
;
; Caution: syscall numbers are undocumented and specific to a particular
; Windows build - regardless of any historical consistency.
;
; Resources:
;	These tables can be directly used:
;	https://github.com/hfiref0x/SyscallTables
;	https://github.com/j00ru/windows-syscalls

SYSCALL_BUILD equ "22621"

if definite SYSCALL_BUILD

	define SYSCALLS SYSCALLS ; searchable namespace

	; the expectation is a name followed by a computable number
	calminstruction reader line&
		match =mvmacro?= any?,line
		jno go
		assemble line
		exit

	go:	match name value,line
		jno unknown
		compute value,value
		arrange name,=SYSCALLS.name
		publish name:,value
		exit
	unknown:
		stringify line
		display "invalid syscall listing: "
		display line
		err
	end calminstruction

	; ntoskrnl service table
	include "x86_64\NT10\ntos\" bappend SYSCALL_BUILD bappend ".txt",\
	mvmacro ?,reader
	mvmacro reader,?

	; Win32k service table
	include "x86_64\NT10\win32k\" bappend SYSCALL_BUILD bappend ".txt",\
	mvmacro ?,reader
	mvmacro reader,?
	purge reader

	calminstruction syscall? function
		transform function,SYSCALLS
		jyes known
		arrange function,=syscall function
		assemble function
		exit

	known:	arrange function,=mov =eax, function
		assemble function
		arrange function,=syscall
		assemble function
	end calminstruction

else
	err "syscall support requires defining SYSCALL_BUILD version string"
end if
