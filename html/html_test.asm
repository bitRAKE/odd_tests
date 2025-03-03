
; https://board.flatassembler.net/topic.php?p=242909#242909

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
iterate STATE,\
	13.2.5.1 Data state,\
	13.2.5.2 RCDATA state,\
	13.2.5.3 RAWTEXT state,\
	13.2.5.4 Script data state,\
	13.2.5.5 PLAINTEXT state,\
	13.2.5.6 Tag open state,\
	13.2.5.7 End tag open state,\
	13.2.5.8 Tag name state,\
	13.2.5.9 RCDATA less-than sign state,\
	13.2.5.10 RCDATA end tag open state,\
	13.2.5.11 RCDATA end tag name state,\
	13.2.5.12 RAWTEXT less-than sign state,\
	13.2.5.13 RAWTEXT end tag open state,\
	13.2.5.14 RAWTEXT end tag name state,\
	13.2.5.15 Script data less-than sign state,\
	13.2.5.16 Script data end tag open state,\
	13.2.5.17 Script data end tag name state,\
	13.2.5.18 Script data escape start state,\
	13.2.5.19 Script data escape start dash state,\
	13.2.5.20 Script data escaped state,\
	13.2.5.21 Script data escaped dash state,\
	13.2.5.22 Script data escaped dash dash state,\
	13.2.5.23 Script data escaped less-than sign state,\
	13.2.5.24 Script data escaped end tag open state,\
	13.2.5.25 Script data escaped end tag name state,\
	13.2.5.26 Script data double escape start state,\
	13.2.5.27 Script data double escaped state,\
	13.2.5.28 Script data double escaped dash state,\
	13.2.5.29 Script data double escaped dash dash state,\
	13.2.5.30 Script data double escaped less-than sign state,\
	13.2.5.31 Script data double escape end state,\
	13.2.5.32 Before attribute name state,\
	13.2.5.33 Attribute name state,\
	13.2.5.34 After attribute name state,\
	13.2.5.35 Before attribute value state,\
	13.2.5.36 Attribute value (double-quoted) state,\
	13.2.5.37 Attribute value (single-quoted) state,\
	13.2.5.38 Attribute value (unquoted) state,\
	13.2.5.39 After attribute value (quoted) state,\
	13.2.5.40 Self-closing start tag state,\
	13.2.5.41 Bogus comment state,\
	13.2.5.42 Markup declaration open state,\
	13.2.5.43 Comment start state,\
	13.2.5.44 Comment start dash state,\
	13.2.5.45 Comment state,\
	13.2.5.46 Comment less-than sign state,\
	13.2.5.47 Comment less-than sign bang state,\
	13.2.5.48 Comment less-than sign bang dash state,\
	13.2.5.49 Comment less-than sign bang dash dash state,\
	13.2.5.50 Comment end dash state,\
	13.2.5.51 Comment end state,\
	13.2.5.52 Comment end bang state,\
	13.2.5.53 DOCTYPE state,\
	13.2.5.54 Before DOCTYPE name state,\
	13.2.5.55 DOCTYPE name state,\
	13.2.5.56 After DOCTYPE name state,\
	13.2.5.57 After DOCTYPE public keyword state,\
	13.2.5.58 Before DOCTYPE public identifier state,\
	13.2.5.59 DOCTYPE public identifier (double-quoted) state,\
	13.2.5.60 DOCTYPE public identifier (single-quoted) state,\
	13.2.5.61 After DOCTYPE public identifier state,\
	13.2.5.62 Between DOCTYPE public and system identifiers state,\
	13.2.5.63 After DOCTYPE system keyword state,\
	13.2.5.64 Before DOCTYPE system identifier state,\
	13.2.5.65 DOCTYPE system identifier (double-quoted) state,\
	13.2.5.66 DOCTYPE system identifier (single-quoted) state,\
	13.2.5.67 After DOCTYPE system identifier state,\
	13.2.5.68 Bogus DOCTYPE state,\
	13.2.5.69 CDATA section state,\
	13.2.5.70 CDATA section bracket state,\
	13.2.5.71 CDATA section end state,\
	13.2.5.72 Character reference state,\
	13.2.5.73 Named character reference state,\
	13.2.5.74 Ambiguous ampersand state,\
	13.2.5.75 Numeric character reference state,\
	13.2.5.76 Hexadecimal character reference start state,\
	13.2.5.77 Decimal character reference start state,\
	13.2.5.78 Hexadecimal character reference state,\
	13.2.5.79 Decimal character reference state,\
	13.2.5.80 Numeric character reference end state

	check_defined STATE
end iterate
end if
