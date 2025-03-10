
; https://board.flatassembler.net/topic.php?p=242909#242909

;	fasm2 html_test.asm

; mock-up for assembly:
format binary
use64
DATA_STATE_INDEX	:= 1
CHAR_REF_STATE_INDEX	:= 2
TAG_OPEN_STATE_INDEX	:= 3

include 'macro/struct.inc'
struct Parser
	tokenizer_return_state	dq ?
	tokenizer_state		dq ?
ends

Parser_emitCharacter:
Parser_emitEof:
Parser_error:

include 'html_states.inc'





macro DISPATCH STATE*
	lea rcx, [HTML_States]
	movzx eax, word [STATE]
	lea rax, [rcx + 8*rax]
	call rax
end macro




if 1 ; audit

calminstruction hex_nibble digit*, command: display
	compute	digit, $FF and '0123456789ABCDEF' shr (digit*8)
	arrange	command, command digit
	assemble command
end calminstruction

calminstruction display_hex_byte value: DATA
	compute	value, value
	local	digit
	compute	digit, (value shr 4) and $F
	call	hex_nibble, digit
	compute	digit, value and $F
	call	hex_nibble, digit
end calminstruction

struc(state) display_printable char*
	; note: space isn't printed because of display abiguity
	if char >= 0x21 & 0x7E >= char ; inclusive
		if ~ state
			display ' '
		end if
		display char
		state = 1
	else
		display ' 0x'
		display_hex_byte char
		state = 0
	end if
end struc

; check which states are used, brute force method
macro check_defined anchor*&
	local dstate, pstate
	repeat 1,N:`anchor
		display 10,`anchor,':'
		dstate = 0
		pstate = 0

		repeat 128,i:0
			if defined ?N.i
				pstate display_printable i
				dstate = 1
			end if
		end repeat
		if defined ?N.ANY
			display ' ANY'
			if defined ?N.EOF
				display ' EOF'
			end if
			dstate = 1
		end if
		if ~ dstate
			display ' UNDEFINED!'
		end if
	end repeat
end macro

display 10,10,'AUDIT:'

irpv _,STATES
	check_defined _
end irpv

repeat 1,m:STATES.minimum,M:STATES.maximum
	display 10,10,'used state range: [',`m,',',`M,']',10
end repeat

end if
