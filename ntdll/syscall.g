format MS64 COFF
section ".text$t" code executable readable align 64

; https://devblogs.microsoft.com/oldnewthing/20041025-00/?p=37483
extrn __ImageBase ; the linker knows

include 'anchor.g'	; aligned data groups
include 'light-fast.g'

include 'macro/struct.inc'
Struct.CheckAlignment = 1

calminstruction ?? line& ; part of anchor, but needs to be here
	match {section:grain} line, line
	jyes datas
	assemble line
	exit
datas:
	arrange line,=COFF=.grain=.section line
	assemble line
	stringify line
end calminstruction

;-------------------------------------------------------------------------------
; Simple SYSCALL wrapper to abstract function numbers.
;
; Caution: syscall numbers are undocumented and specific to a particular
; Windows build - regardless of any historical consistency.
;
; Resources:
;	These tables can be directly used:
;	https://github.com/hfiref0x/SyscallTables
;	https://github.com/j00ru/windows-syscalls

if definite SYSCALL_BUILD

	define SYSCALLS SYSCALLS ; searchable namespace
	namespace SYSCALLS

	; the expectation is a name followed by a computable number
	calminstruction reader line&
		match =mvmacro?= any?,line
		jno go
		assemble line
		exit

	go:	match name value,line
		jno unknown
		compute value,value
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

	end namespace ; SYSCALLS

	calminstruction syscall? function
;		transform function,SYSCALLS
;		jyes known
;		display 'x'
;		arrange function,=syscall function
;		assemble function
;		exit

	known:	arrange function,=mov =eax, =SYSCALLS.function
		assemble function
		arrange function,=syscall
		assemble function
	end calminstruction

else
	err "syscall support requires defining SYSCALL_BUILD version string"
end if
