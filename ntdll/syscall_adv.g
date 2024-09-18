if ~ definite SYSCALL_BUILD
	err "syscall support requires defining SYSCALL_BUILD version string"
end if

;-------------------------------------------------------------------------------
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


define SYSCALLS SYSCALLS ; searchable namespace
namespace SYSCALLS
	; the expectation is a name followed by a number
	macro reader line&
		match =MVMACRO?= any =, any,line
			line
		else match name= value,line
			; generic stub for each function
			calminstruction name params&
				call SYSCALLS.DISPATCH value,params
			end calminstruction
		else
			err "syscall table error: ",`line,10
		end match
	end macro

	; ntoskrnl service table
	include "x86_64\NT10\ntos\" bappend SYSCALL_BUILD bappend ".txt",\
	mvmacro ?,reader
	mvmacro reader,?

	; Win32k service table
	include "x86_64\NT10\win32k\" bappend SYSCALL_BUILD bappend ".txt",\
	mvmacro ?,reader
	mvmacro reader,?

	purge reader

; Reverse indexing changes the way we should prep: target registers should be
; intermediaries for later parameters (if needed). RCX|RAX shouldn't be used.
	macro DISPATCH index*,line&
		; process function parameters
		iterate PARM,line
			if % = %% & (8*%%) > (8*fastcall?.frame)
				; max stack depth needed
				fastcall?.frame = 8*(%% + (%% and 1))
			end if
			pno = %% - % + 1
			indx pno ; select parameter

			iterate RUSE, r10,rdx,r8,r9,rcx,rax
				if pno < 5
					indx pno ; select register column
					SYSCALLS.PARAMETER RUSE,,PARM
				else ; alternate volatile register proxy
					indx 5 + ((pno-4) mod 2)
					SYSCALLS.PARAMETER [rsp+pno*8],RUSE,PARM
				end if
				break
			end iterate
		end iterate
		mov eax,index
		syscall
	end macro

; https://github.com/tgrysztar/fasm2/blob/master/include/macro/proc64.inc
; <any>		address of abstract constant
; & name	address of existing data
; float any	word/single/double
; immediate	number
; [any]		memory
	macro PARAMETER dest*,alt,src*
		local value
		value equ src
		match < val >, src ; address of abstract constant
			value reequ val
			SYSCALLS.INLINE_CONST value ; instance constant
			type = 'a'
		else match =& val, src
			value reequ val
;			x86.parse_operand@src [val]
			type = 'a'
		else match =float? val, src
			value reequ val
			SSE.parse_operand@src val
			type = 'f'
		else match val =, val, src ; shouldn't happen?
			err "wrap abstract collection in <>"
		else
			SSE.parse_operand@src src
			if @src.type = 'imm' & @src.size = 0
				if value eqtype ''
					err "abstract string needs decoration"
				end if
			end if
			type = 0
		end match
		if type = 'a'
			match ,alt
				lea dest,[value]
			else
				lea alt,[value]
				mov dest,alt
			end match
		else if type = 'f'
			movd fastcall.rf#%,value
			movq fastcall.rf#%,value
		else
		end if
		
	end macro

; https://learn.microsoft.com/en-us/archive/blogs/ericlippert/erics-complete-guide-to-bstr-semantics

macro INLINE_CONST line&
	local data,bytes,_string
	match value, line

	match =W rest,line ; wide character string
		COFF.2.CONST data du value,0
		redefine var data
	else match =A rest,line ; narrow character string
		COFF.1.CONST data db value,0
		redefine var data
	else match =B rest,line ; BSTR (COM basic string)
		COFF.2.CONST dd bytes
		COFF.2.CONST data du value,0
		COFF.2.CONST bytes := $ - data - 2
		redefine var data
	else match =U rest,line ; UNICODE_STRING
; ANSI_STRING is similar, but for narrow strings.
		COFF.8.CONST _string dw bytes-2,bytes,0,0
		COFF.8.CONST	dq data
		COFF.2.CONST data du value,0
		COFF.2.CONST bytes := $ - data
		redefine var _string
	else match {anchor:bytes} name rest,line ; specific placement
;		COFF.bytes.anchor name rest
		line
		redefine var name
	else ; general constant data, dynamic placement
		virtual at 0
			line
			bytes := $
		end virtual
		bytes = 1 shl (bsf (bytes or 64)) ; alignment range
		repeat 1,B:bytes
			COFF.B.CONST data value
			redefine var data
		end repeat
	end match
	end match
end macro

end namespace ; SYSCALLS
