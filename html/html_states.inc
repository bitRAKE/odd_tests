
include 'html_states.g' ; macro support


; Reference:
;	https://html.spec.whatwg.org/multipage/parsing.html#tokenization

state	13.2.5.1 Data state
; Consume the next input character:

	U+0026 AMPERSAND (&)
	; Set the return state to the data state. Switch to the character reference state.
		mov [r12 + Parser.tokenizer_return_state], DATA_STATE_INDEX
		mov [r12 + Parser.tokenizer_state], CHAR_REF_STATE_INDEX
		xor eax,eax
		ret

	U+003C LESS-THAN SIGN (<)
	; Switch to the tag open state.
		mov [r12 + Parser.tokenizer_state], TAG_OPEN_STATE_INDEX
		xor eax,eax
		ret

	U+0000 NULL
	; This is an unexpected-null-character parse error. Emit the current input character as a character token.
		push rdi
		call Parser_error
		pop rdi
		call Parser_emitCharacter
		xor eax,eax
		ret

;	EOF
;	; Emit an end-of-file token.
;		jmp Parser_emitEof

	EOF equ Parser_emitEof ; save a JMP by short-cutting the reference

	Anything else
	; Emit the current input character as a character token.
		call  Parser_emitCharacter
		xor eax,eax
		ret

end state




state	13.2.5.2 RCDATA state
; Consume the next input character:

	U+0026 AMPERSAND (&)
	; Set the return state to the RCDATA state. Switch to the character reference state.

	U+003C LESS-THAN SIGN (<)
	; Switch to the RCDATA less-than sign state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Emit a U+FFFD REPLACEMENT CHARACTER character token.

	EOF
	; Emit an end-of-file token.

	Anything else
	; Emit the current input character as a character token.

end state


state	13.2.5.3 RAWTEXT state
; Consume the next input character:

	U+003C LESS-THAN SIGN (<)
	; Switch to the RAWTEXT less-than sign state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Emit a U+FFFD REPLACEMENT CHARACTER character token.

	EOF
	; Emit an end-of-file token.

	Anything else
	; Emit the current input character as a character token.

end state


state	13.2.5.4 Script data state
; Consume the next input character:

	U+003C LESS-THAN SIGN (<)
	; Switch to the script data less-than sign state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Emit a U+FFFD REPLACEMENT CHARACTER character token.

	EOF
	; Emit an end-of-file token.

	Anything else
	; Emit the current input character as a character token.

end state


state	13.2.5.5 PLAINTEXT state
; Consume the next input character:

	U+0000 NULL
	; This is an unexpected-null-character parse error. Emit a U+FFFD REPLACEMENT CHARACTER character token.

	EOF
	; Emit an end-of-file token.

	Anything else
	; Emit the current input character as a character token.

end state


state	13.2.5.6 Tag open state
; Consume the next input character:

	U+0021 EXCLAMATION MARK (!)
	; Switch to the markup declaration open state.

	U+002F SOLIDUS (/)
	; Switch to the end tag open state.

	ASCII alpha
	; Create a new start tag token, set its tag name to the empty string. Reconsume in the tag name state.

	U+003F QUESTION MARK (?)
	; This is an unexpected-question-mark-instead-of-tag-name parse error. Create a comment token whose data is the empty string. Reconsume in the bogus comment state.

	EOF
	; This is an eof-before-tag-name parse error. Emit a U+003C LESS-THAN SIGN character token and an end-of-file token.

	Anything else
	; This is an invalid-first-character-of-tag-name parse error. Emit a U+003C LESS-THAN SIGN character token. Reconsume in the data state.

end state


state	13.2.5.7 End tag open state
; Consume the next input character:

	ASCII alpha
	; Create a new end tag token, set its tag name to the empty string. Reconsume in the tag name state.

	U+003E GREATER-THAN SIGN (>)
	; This is a missing-end-tag-name parse error. Switch to the data state.

	EOF
	; This is an eof-before-tag-name parse error. Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token and an end-of-file token.

	Anything else
	; This is an invalid-first-character-of-tag-name parse error. Create a comment token whose data is the empty string. Reconsume in the bogus comment state.

end state


state	13.2.5.8 Tag name state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Switch to the before attribute name state.

	U+002F SOLIDUS (/)
	; Switch to the self-closing start tag state.

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state. Emit the current tag token.

	ASCII upper alpha
	; Append the lowercase version of the current input character (add 0x0020 to the character's code point) to the current tag token's tag name.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current tag token's tag name.

	EOF
	; This is an eof-in-tag parse error. Emit an end-of-file token.

	Anything else
	; Append the current input character to the current tag token's tag name.

end state


state	13.2.5.9 RCDATA less-than sign state
; Consume the next input character:

	U+002F SOLIDUS (/)
	; Set the temporary buffer to the empty string. Switch to the RCDATA end tag open state.

	Anything else
	; Emit a U+003C LESS-THAN SIGN character token. Reconsume in the RCDATA state.

end state


state	13.2.5.10 RCDATA end tag open state
; Consume the next input character:

	ASCII alpha
	; Create a new end tag token, set its tag name to the empty string. Reconsume in the RCDATA end tag name state.

	Anything else
	; Emit a U+003C LESS-THAN SIGN character token and a U+002F SOLIDUS character token. Reconsume in the RCDATA state.

end state


state	13.2.5.11 RCDATA end tag name state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; If the current end tag token is an appropriate end tag token, then switch to the before attribute name state. Otherwise, treat it as per the "anything else" entry below.
;		mov rax, [END_TAG_TOKEN]
;		test [rax + Tag_Token.Flags], TT_APPROPRIATE
		jz ANY ; state local "anything else"
;		.state GET_STATE 13.2.5.32 Before attribute name state
;		mov [r12 + Parser.tokenizer_state], .state
		xor eax,eax
		retn

	U+002F SOLIDUS (/)
	; If the current end tag token is an appropriate end tag token, then switch to the self-closing start tag state. Otherwise, treat it as per the "anything else" entry below.

	U+003E GREATER-THAN SIGN (>)
	; If the current end tag token is an appropriate end tag token, then switch to the data state and emit the current tag token. Otherwise, treat it as per the "anything else" entry below.

	ASCII upper alpha
	; Append the lowercase version of the current input character (add 0x0020 to the character's code point) to the current tag token's tag name. Append the current input character to the temporary buffer.

	ASCII lower alpha
	; Append the current input character to the current tag token's tag name. Append the current input character to the temporary buffer.

	Anything else
	; Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token, and a character token for each of the characters in the temporary buffer (in the order they were added to the buffer). Reconsume in the RCDATA state.

end state


state	13.2.5.12 RAWTEXT less-than sign state
; Consume the next input character:

	U+002F SOLIDUS (/)
	; Set the temporary buffer to the empty string. Switch to the RAWTEXT end tag open state.

	Anything else
	; Emit a U+003C LESS-THAN SIGN character token. Reconsume in the RAWTEXT state.

end state


state	13.2.5.13 RAWTEXT end tag open state
; Consume the next input character:

	ASCII alpha
	; Create a new end tag token, set its tag name to the empty string. Reconsume in the RAWTEXT end tag name state.

	Anything else
	; Emit a U+003C LESS-THAN SIGN character token and a U+002F SOLIDUS character token. Reconsume in the RAWTEXT state.

end state


state	13.2.5.14 RAWTEXT end tag name state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; If the current end tag token is an appropriate end tag token, then switch to the before attribute name state. Otherwise, treat it as per the "anything else" entry below.

	U+002F SOLIDUS (/)
	; If the current end tag token is an appropriate end tag token, then switch to the self-closing start tag state. Otherwise, treat it as per the "anything else" entry below.

	U+003E GREATER-THAN SIGN (>)
	; If the current end tag token is an appropriate end tag token, then switch to the data state and emit the current tag token. Otherwise, treat it as per the "anything else" entry below.

	ASCII upper alpha
	; Append the lowercase version of the current input character (add 0x0020 to the character's code point) to the current tag token's tag name. Append the current input character to the temporary buffer.

	ASCII lower alpha
	; Append the current input character to the current tag token's tag name. Append the current input character to the temporary buffer.

	Anything else
	; Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token, and a character token for each of the characters in the temporary buffer (in the order they were added to the buffer). Reconsume in the RAWTEXT state.

end state


state	13.2.5.15 Script data less-than sign state
; Consume the next input character:

	U+002F SOLIDUS (/)
	; Set the temporary buffer to the empty string. Switch to the script data end tag open state.

	U+0021 EXCLAMATION MARK (!)
	; Switch to the script data escape start state. Emit a U+003C LESS-THAN SIGN character token and a U+0021 EXCLAMATION MARK character token.

	Anything else
	; Emit a U+003C LESS-THAN SIGN character token. Reconsume in the script data state.

end state


state	13.2.5.16 Script data end tag open state
; Consume the next input character:

	ASCII alpha
	; Create a new end tag token, set its tag name to the empty string. Reconsume in the script data end tag name state.

	Anything else
	; Emit a U+003C LESS-THAN SIGN character token and a U+002F SOLIDUS character token. Reconsume in the script data state.

end state


state	13.2.5.17 Script data end tag name state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; If the current end tag token is an appropriate end tag token, then switch to the before attribute name state. Otherwise, treat it as per the "anything else" entry below.

	U+002F SOLIDUS (/)
	; If the current end tag token is an appropriate end tag token, then switch to the self-closing start tag state. Otherwise, treat it as per the "anything else" entry below.

	U+003E GREATER-THAN SIGN (>)
	; If the current end tag token is an appropriate end tag token, then switch to the data state and emit the current tag token. Otherwise, treat it as per the "anything else" entry below.

	ASCII upper alpha
	; Append the lowercase version of the current input character (add 0x0020 to the character's code point) to the current tag token's tag name. Append the current input character to the temporary buffer.

	ASCII lower alpha
	; Append the current input character to the current tag token's tag name. Append the current input character to the temporary buffer.

	Anything else
	; Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token, and a character token for each of the characters in the temporary buffer (in the order they were added to the buffer). Reconsume in the script data state.

end state


state	13.2.5.18 Script data escape start state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Switch to the script data escape start dash state. Emit a U+002D HYPHEN-MINUS character token.

	Anything else
	; Reconsume in the script data state.

end state


state	13.2.5.19 Script data escape start dash state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Switch to the script data escaped dash dash state. Emit a U+002D HYPHEN-MINUS character token.

	Anything else
	; Reconsume in the script data state.

end state


state	13.2.5.20 Script data escaped state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Switch to the script data escaped dash state. Emit a U+002D HYPHEN-MINUS character token.

	U+003C LESS-THAN SIGN (<)
	; Switch to the script data escaped less-than sign state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Emit a U+FFFD REPLACEMENT CHARACTER character token.

	EOF
	; This is an eof-in-script-html-comment-like-text parse error. Emit an end-of-file token.

	Anything else
	; Emit the current input character as a character token.

end state


state	13.2.5.21 Script data escaped dash state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Switch to the script data escaped dash dash state. Emit a U+002D HYPHEN-MINUS character token.

	U+003C LESS-THAN SIGN (<)
	; Switch to the script data escaped less-than sign state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Switch to the script data escaped state. Emit a U+FFFD REPLACEMENT CHARACTER character token.

	EOF
	; This is an eof-in-script-html-comment-like-text parse error. Emit an end-of-file token.

	Anything else
	; Switch to the script data escaped state. Emit the current input character as a character token.

end state


state	13.2.5.22 Script data escaped dash dash state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Emit a U+002D HYPHEN-MINUS character token.

	U+003C LESS-THAN SIGN (<)
	; Switch to the script data escaped less-than sign state.

	U+003E GREATER-THAN SIGN (>)
	; Switch to the script data state. Emit a U+003E GREATER-THAN SIGN character token.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Switch to the script data escaped state. Emit a U+FFFD REPLACEMENT CHARACTER character token.

	EOF
	; This is an eof-in-script-html-comment-like-text parse error. Emit an end-of-file token.

	Anything else
	; Switch to the script data escaped state. Emit the current input character as a character token.

end state


state	13.2.5.23 Script data escaped less-than sign state
; Consume the next input character:

	U+002F SOLIDUS (/)
	; Set the temporary buffer to the empty string. Switch to the script data escaped end tag open state.

	ASCII alpha
	; Set the temporary buffer to the empty string. Emit a U+003C LESS-THAN SIGN character token. Reconsume in the script data double escape start state.

	Anything else
	; Emit a U+003C LESS-THAN SIGN character token. Reconsume in the script data escaped state.

end state


state	13.2.5.24 Script data escaped end tag open state
; Consume the next input character:

	ASCII alpha
	; Create a new end tag token, set its tag name to the empty string. Reconsume in the script data escaped end tag name state.

	Anything else
	; Emit a U+003C LESS-THAN SIGN character token and a U+002F SOLIDUS character token. Reconsume in the script data escaped state.

end state


state	13.2.5.25 Script data escaped end tag name state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; If the current end tag token is an appropriate end tag token, then switch to the before attribute name state. Otherwise, treat it as per the "anything else" entry below.

	U+002F SOLIDUS (/)
	; If the current end tag token is an appropriate end tag token, then switch to the self-closing start tag state. Otherwise, treat it as per the "anything else" entry below.

	U+003E GREATER-THAN SIGN (>)
	; If the current end tag token is an appropriate end tag token, then switch to the data state and emit the current tag token. Otherwise, treat it as per the "anything else" entry below.

	ASCII upper alpha
	; Append the lowercase version of the current input character (add 0x0020 to the character's code point) to the current tag token's tag name. Append the current input character to the temporary buffer.

	ASCII lower alpha
	; Append the current input character to the current tag token's tag name. Append the current input character to the temporary buffer.

	Anything else
	; Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token, and a character token for each of the characters in the temporary buffer (in the order they were added to the buffer). Reconsume in the script data escaped state.

end state


state	13.2.5.26 Script data double escape start state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	U+002F SOLIDUS (/)
	U+003E GREATER-THAN SIGN (>)
	; If the temporary buffer is the string "script", then switch to the script data double escaped state. Otherwise, switch to the script data escaped state. Emit the current input character as a character token.

	ASCII upper alpha
	; Append the lowercase version of the current input character (add 0x0020 to the character's code point) to the temporary buffer. Emit the current input character as a character token.

	ASCII lower alpha
	; Append the current input character to the temporary buffer. Emit the current input character as a character token.

	Anything else
	; Reconsume in the script data escaped state.

end state


state	13.2.5.27 Script data double escaped state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Switch to the script data double escaped dash state. Emit a U+002D HYPHEN-MINUS character token.

	U+003C LESS-THAN SIGN (<)
	; Switch to the script data double escaped less-than sign state. Emit a U+003C LESS-THAN SIGN character token.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Emit a U+FFFD REPLACEMENT CHARACTER character token.

	EOF
	; This is an eof-in-script-html-comment-like-text parse error. Emit an end-of-file token.

	Anything else
	; Emit the current input character as a character token.

end state


state	13.2.5.28 Script data double escaped dash state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Switch to the script data double escaped dash dash state. Emit a U+002D HYPHEN-MINUS character token.

	U+003C LESS-THAN SIGN (<)
	; Switch to the script data double escaped less-than sign state. Emit a U+003C LESS-THAN SIGN character token.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Switch to the script data double escaped state. Emit a U+FFFD REPLACEMENT CHARACTER character token.

	EOF
	; This is an eof-in-script-html-comment-like-text parse error. Emit an end-of-file token.

	Anything else
	; Switch to the script data double escaped state. Emit the current input character as a character token.

end state


state	13.2.5.29 Script data double escaped dash dash state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Emit a U+002D HYPHEN-MINUS character token.

	U+003C LESS-THAN SIGN (<)
	; Switch to the script data double escaped less-than sign state. Emit a U+003C LESS-THAN SIGN character token.

	U+003E GREATER-THAN SIGN (>)
	; Switch to the script data state. Emit a U+003E GREATER-THAN SIGN character token.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Switch to the script data double escaped state. Emit a U+FFFD REPLACEMENT CHARACTER character token.

	EOF
	; This is an eof-in-script-html-comment-like-text parse error. Emit an end-of-file token.

	Anything else
	; Switch to the script data double escaped state. Emit the current input character as a character token.

end state


state	13.2.5.30 Script data double escaped less-than sign state
; Consume the next input character:

	U+002F SOLIDUS (/)
	; Set the temporary buffer to the empty string. Switch to the script data double escape end state. Emit a U+002F SOLIDUS character token.

	Anything else
	; Reconsume in the script data double escaped state.

end state


state	13.2.5.31 Script data double escape end state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	U+002F SOLIDUS (/)
	U+003E GREATER-THAN SIGN (>)
	; If the temporary buffer is the string "script", then switch to the script data escaped state. Otherwise, switch to the script data double escaped state. Emit the current input character as a character token.

	ASCII upper alpha
	; Append the lowercase version of the current input character (add 0x0020 to the character's code point) to the temporary buffer. Emit the current input character as a character token.

	ASCII lower alpha
	; Append the current input character to the temporary buffer. Emit the current input character as a character token.

	Anything else
	; Reconsume in the script data double escaped state.

end state


state	13.2.5.32 Before attribute name state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Ignore the character.

	U+002F SOLIDUS (/)
	U+003E GREATER-THAN SIGN (>)
	EOF
	; Reconsume in the after attribute name state.

	U+003D EQUALS SIGN (=)
	; This is an unexpected-equals-sign-before-attribute-name parse error. Start a new attribute in the current tag token. Set that attribute's name to the current input character, and its value to the empty string. Switch to the attribute name state.

	Anything else
	; Start a new attribute in the current tag token. Set that attribute name and value to the empty string. Reconsume in the attribute name state.

end state


state	13.2.5.33 Attribute name state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	U+002F SOLIDUS (/)
	U+003E GREATER-THAN SIGN (>)
	EOF
	; Reconsume in the after attribute name state.

	U+003D EQUALS SIGN (=)
	; Switch to the before attribute value state.

	ASCII upper alpha
	; Append the lowercase version of the current input character (add 0x0020 to the character's code point) to the current attribute's name.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current attribute's name.

	U+0022 QUOTATION MARK (")
	U+0027 APOSTROPHE (')
	U+003C LESS-THAN SIGN (<)
	; This is an unexpected-character-in-attribute-name parse error. Treat it as per the "anything else" entry below.

	Anything else
	; Append the current input character to the current attribute's name.
	; When the user agent leaves the attribute name state (and before emitting the tag token, if appropriate), the complete attribute's name must be compared to the other attributes on the same token; if there is already an attribute on the token with the exact same name, then this is a duplicate-attribute parse error and the new attribute must be removed from the token.

	; If an attribute is so removed from a token, it, and the value that gets associated with it, if any, are never subsequently used by the parser, and are therefore effectively discarded. Removing the attribute in this way does not change its status as the "current attribute" for the purposes of the tokenizer, however.

end state


state	13.2.5.34 After attribute name state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Ignore the character.

	U+002F SOLIDUS (/)
	; Switch to the self-closing start tag state.

	U+003D EQUALS SIGN (=)
	; Switch to the before attribute value state.

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state. Emit the current tag token.

	EOF
	; This is an eof-in-tag parse error. Emit an end-of-file token.

	Anything else
	; Start a new attribute in the current tag token. Set that attribute name and value to the empty string. Reconsume in the attribute name state.

end state


state	13.2.5.35 Before attribute value state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Ignore the character.

	U+0022 QUOTATION MARK (")
	; Switch to the attribute value (double-quoted) state.

	U+0027 APOSTROPHE (')
	; Switch to the attribute value (single-quoted) state.

	U+003E GREATER-THAN SIGN (>)
	; This is a missing-attribute-value parse error. Switch to the data state. Emit the current tag token.

	Anything else
	; Reconsume in the attribute value (unquoted) state.

end state


state	13.2.5.36 Attribute value (double-quoted) state
; Consume the next input character:

	U+0022 QUOTATION MARK (")
	; Switch to the after attribute value (quoted) state.

	U+0026 AMPERSAND (&)
	; Set the return state to the attribute value (double-quoted) state. Switch to the character reference state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current attribute's value.

	EOF
	; This is an eof-in-tag parse error. Emit an end-of-file token.

	Anything else
	; Append the current input character to the current attribute's value.

end state


state	13.2.5.37 Attribute value (single-quoted) state
; Consume the next input character:

	U+0027 APOSTROPHE (')
	; Switch to the after attribute value (quoted) state.

	U+0026 AMPERSAND (&)
	; Set the return state to the attribute value (single-quoted) state. Switch to the character reference state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current attribute's value.

	EOF
	; This is an eof-in-tag parse error. Emit an end-of-file token.

	Anything else
	; Append the current input character to the current attribute's value.

end state


state	13.2.5.38 Attribute value (unquoted) state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Switch to the before attribute name state.

	U+0026 AMPERSAND (&)
	; Set the return state to the attribute value (unquoted) state. Switch to the character reference state.

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state. Emit the current tag token.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current attribute's value.

	U+0022 QUOTATION MARK (")
	U+0027 APOSTROPHE (')
	U+003C LESS-THAN SIGN (<)
	U+003D EQUALS SIGN (=)
	U+0060 GRAVE ACCENT (`)
	; This is an unexpected-character-in-unquoted-attribute-value parse error. Treat it as per the "anything else" entry below.

	EOF
	; This is an eof-in-tag parse error. Emit an end-of-file token.

	Anything else
	; Append the current input character to the current attribute's value.

end state


state	13.2.5.39 After attribute value (quoted) state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Switch to the before attribute name state.

	U+002F SOLIDUS (/)
	; Switch to the self-closing start tag state.

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state. Emit the current tag token.

	EOF
	; This is an eof-in-tag parse error. Emit an end-of-file token.

	Anything else
	; This is a missing-whitespace-between-attributes parse error. Reconsume in the before attribute name state.

end state


state	13.2.5.40 Self-closing start tag state
; Consume the next input character:

	U+003E GREATER-THAN SIGN (>)
	; Set the self-closing flag of the current tag token. Switch to the data state. Emit the current tag token.

	EOF
	; This is an eof-in-tag parse error. Emit an end-of-file token.

	Anything else
	; This is an unexpected-solidus-in-tag parse error. Reconsume in the before attribute name state.

end state


state	13.2.5.41 Bogus comment state
;Consume the next input character:

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state. Emit the current comment token.

	EOF
	; Emit the comment. Emit an end-of-file token.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the comment token's data.

	Anything else
	; Append the current input character to the comment token's data.

end state


state	13.2.5.42 Markup declaration open state
; If the next few characters are:

;	Two U+002D HYPHEN-MINUS characters (-)
;	Consume those two characters, create a comment token whose data is the empty string, and switch to the comment start state.

;	ASCII case-insensitive match for the word "DOCTYPE"
;	Consume those characters and switch to the DOCTYPE state.

;	The string "[CDATA[" (the five uppercase letters "CDATA" with a U+005B LEFT SQUARE BRACKET character before and after)
;	Consume those characters. If there is an adjusted current node and it is not an element in the HTML namespace, then switch to the CDATA section state. Otherwise, this is a cdata-in-html-content parse error. Create a comment token whose data is the "[CDATA[" string. Switch to the bogus comment state.

	Anything else
	; This is an incorrectly-opened-comment parse error. Create a comment token whose data is the empty string. Switch to the bogus comment state (don't consume anything in the current state).

end state


state	13.2.5.43 Comment start state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Switch to the comment start dash state.

	U+003E GREATER-THAN SIGN (>)
	; This is an abrupt-closing-of-empty-comment parse error. Switch to the data state. Emit the current comment token.

	Anything else
	; Reconsume in the comment state.

end state


state	13.2.5.44 Comment start dash state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Switch to the comment end state.

	U+003E GREATER-THAN SIGN (>)
	; This is an abrupt-closing-of-empty-comment parse error. Switch to the data state. Emit the current comment token.

	EOF
	; This is an eof-in-comment parse error. Emit the current comment token. Emit an end-of-file token.

	Anything else
	; Append a U+002D HYPHEN-MINUS character (-) to the comment token's data. Reconsume in the comment state.

end state


state	13.2.5.45 Comment state
; Consume the next input character:

	U+003C LESS-THAN SIGN (<)
	; Append the current input character to the comment token's data. Switch to the comment less-than sign state.

	U+002D HYPHEN-MINUS (-)
	; Switch to the comment end dash state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the comment token's data.

	EOF
	; This is an eof-in-comment parse error. Emit the current comment token. Emit an end-of-file token.

	Anything else
	; Append the current input character to the comment token's data.
end state


state	13.2.5.46 Comment less-than sign state
; Consume the next input character:

	U+0021 EXCLAMATION MARK (!)
	; Append the current input character to the comment token's data. Switch to the comment less-than sign bang state.

	U+003C LESS-THAN SIGN (<)
	; Append the current input character to the comment token's data.

	Anything else
	; Reconsume in the comment state.

end state


state	13.2.5.47 Comment less-than sign bang state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Switch to the comment less-than sign bang dash state.

	Anything else
	; Reconsume in the comment state.

end state


state	13.2.5.48 Comment less-than sign bang dash state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Switch to the comment less-than sign bang dash dash state.

	Anything else
	; Reconsume in the comment end dash state.

end state


state	13.2.5.49 Comment less-than sign bang dash dash state
; Consume the next input character:

	U+003E GREATER-THAN SIGN (>)
	EOF
	; Reconsume in the comment end state.

	Anything else
	; This is a nested-comment parse error. Reconsume in the comment end state.

end state


state	13.2.5.50 Comment end dash state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Switch to the comment end state.

	EOF
	; This is an eof-in-comment parse error. Emit the current comment token. Emit an end-of-file token.

	Anything else
	; Append a U+002D HYPHEN-MINUS character (-) to the comment token's data. Reconsume in the comment state.

end state


state	13.2.5.51 Comment end state
; Consume the next input character:

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state. Emit the current comment token.

	U+0021 EXCLAMATION MARK (!)
	; Switch to the comment end bang state.

	U+002D HYPHEN-MINUS (-)
	; Append a U+002D HYPHEN-MINUS character (-) to the comment token's data.

	EOF
	; This is an eof-in-comment parse error. Emit the current comment token. Emit an end-of-file token.

	Anything else
	; Append two U+002D HYPHEN-MINUS characters (-) to the comment token's data. Reconsume in the comment state.

end state


state	13.2.5.52 Comment end bang state
; Consume the next input character:

	U+002D HYPHEN-MINUS (-)
	; Append two U+002D HYPHEN-MINUS characters (-) and a U+0021 EXCLAMATION MARK character (!) to the comment token's data. Switch to the comment end dash state.

	U+003E GREATER-THAN SIGN (>)
	; This is an incorrectly-closed-comment parse error. Switch to the data state. Emit the current comment token.

	EOF
	; This is an eof-in-comment parse error. Emit the current comment token. Emit an end-of-file token.

	Anything else
	; Append two U+002D HYPHEN-MINUS characters (-) and a U+0021 EXCLAMATION MARK character (!) to the comment token's data. Reconsume in the comment state.

end state


state	13.2.5.53 DOCTYPE state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Switch to the before DOCTYPE name state.

	U+003E GREATER-THAN SIGN (>)
	; Reconsume in the before DOCTYPE name state.

	EOF
	; This is an eof-in-doctype parse error. Create a new DOCTYPE token. Set its force-quirks flag to on. Emit the current token. Emit an end-of-file token.

	Anything else
	; This is a missing-whitespace-before-doctype-name parse error. Reconsume in the before DOCTYPE name state.

end state


state	13.2.5.54 Before DOCTYPE name state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Ignore the character.

	ASCII upper alpha
	; Create a new DOCTYPE token. Set the token's name to the lowercase version of the current input character (add 0x0020 to the character's code point). Switch to the DOCTYPE name state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Create a new DOCTYPE token. Set the token's name to a U+FFFD REPLACEMENT CHARACTER character. Switch to the DOCTYPE name state.

	U+003E GREATER-THAN SIGN (>)
	; This is a missing-doctype-name parse error. Create a new DOCTYPE token. Set its force-quirks flag to on. Switch to the data state. Emit the current token.

	EOF
	; This is an eof-in-doctype parse error. Create a new DOCTYPE token. Set its force-quirks flag to on. Emit the current token. Emit an end-of-file token.

	Anything else
	; Create a new DOCTYPE token. Set the token's name to the current input character. Switch to the DOCTYPE name state.

end state


state	13.2.5.55 DOCTYPE name state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Switch to the after DOCTYPE name state.

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state. Emit the current DOCTYPE token.

	ASCII upper alpha
	; Append the lowercase version of the current input character (add 0x0020 to the character's code point) to the current DOCTYPE token's name.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current DOCTYPE token's name.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; Append the current input character to the current DOCTYPE token's name.

end state


state	13.2.5.56 After DOCTYPE name state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Ignore the character.

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state. Emit the current DOCTYPE token.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; If the six characters starting from the current input character are an ASCII case-insensitive match for the word "PUBLIC", then consume those characters and switch to the after DOCTYPE public keyword state.
	;
	; Otherwise, if the six characters starting from the current input character are an ASCII case-insensitive match for the word "SYSTEM", then consume those characters and switch to the after DOCTYPE system keyword state.
	;
	; Otherwise, this is an invalid-character-sequence-after-doctype-name parse error. Set the current DOCTYPE token's force-quirks flag to on. Reconsume in the bogus DOCTYPE state.

end state


state	13.2.5.57 After DOCTYPE public keyword state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Switch to the before DOCTYPE public identifier state.

	U+0022 QUOTATION MARK (")
	; This is a missing-whitespace-after-doctype-public-keyword parse error. Set the current DOCTYPE token's public identifier to the empty string (not missing), then switch to the DOCTYPE public identifier (double-quoted) state.

	U+0027 APOSTROPHE (')
	; This is a missing-whitespace-after-doctype-public-keyword parse error. Set the current DOCTYPE token's public identifier to the empty string (not missing), then switch to the DOCTYPE public identifier (single-quoted) state.

	U+003E GREATER-THAN SIGN (>)
	; This is a missing-doctype-public-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit the current DOCTYPE token.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; This is a missing-quote-before-doctype-public-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Reconsume in the bogus DOCTYPE state.

end state


state	13.2.5.58 Before DOCTYPE public identifier state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Ignore the character.

	U+0022 QUOTATION MARK (")
	; Set the current DOCTYPE token's public identifier to the empty string (not missing), then switch to the DOCTYPE public identifier (double-quoted) state.

	U+0027 APOSTROPHE (')
	; Set the current DOCTYPE token's public identifier to the empty string (not missing), then switch to the DOCTYPE public identifier (single-quoted) state.

	U+003E GREATER-THAN SIGN (>)
	; This is a missing-doctype-public-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit the current DOCTYPE token.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; This is a missing-quote-before-doctype-public-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Reconsume in the bogus DOCTYPE state.

end state


state	13.2.5.59 DOCTYPE public identifier (double-quoted) state
; Consume the next input character:

	U+0022 QUOTATION MARK (")
	; Switch to the after DOCTYPE public identifier state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current DOCTYPE token's public identifier.

	U+003E GREATER-THAN SIGN (>)
	; This is an abrupt-doctype-public-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit the current DOCTYPE token.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; Append the current input character to the current DOCTYPE token's public identifier.

end state


state	13.2.5.60 DOCTYPE public identifier (single-quoted) state
; Consume the next input character:

	U+0027 APOSTROPHE (')
	; Switch to the after DOCTYPE public identifier state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current DOCTYPE token's public identifier.

	U+003E GREATER-THAN SIGN (>)
	; This is an abrupt-doctype-public-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit the current DOCTYPE token.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; Append the current input character to the current DOCTYPE token's public identifier.

end state


state	13.2.5.61 After DOCTYPE public identifier state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Switch to the between DOCTYPE public and system identifiers state.

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state. Emit the current DOCTYPE token.

	U+0022 QUOTATION MARK (")
	; This is a missing-whitespace-between-doctype-public-and-system-identifiers parse error. Set the current DOCTYPE token's system identifier to the empty string (not missing), then switch to the DOCTYPE system identifier (double-quoted) state.

	U+0027 APOSTROPHE (')
	; This is a missing-whitespace-between-doctype-public-and-system-identifiers parse error. Set the current DOCTYPE token's system identifier to the empty string (not missing), then switch to the DOCTYPE system identifier (single-quoted) state.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; This is a missing-quote-before-doctype-system-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Reconsume in the bogus DOCTYPE state.

end state


state	13.2.5.62 Between DOCTYPE public and system identifiers state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Ignore the character.

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state. Emit the current DOCTYPE token.

	U+0022 QUOTATION MARK (")
	; Set the current DOCTYPE token's system identifier to the empty string (not missing), then switch to the DOCTYPE system identifier (double-quoted) state.

	U+0027 APOSTROPHE (')
	; Set the current DOCTYPE token's system identifier to the empty string (not missing), then switch to the DOCTYPE system identifier (single-quoted) state.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; This is a missing-quote-before-doctype-system-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Reconsume in the bogus DOCTYPE state.

end state


state	13.2.5.63 After DOCTYPE system keyword state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Switch to the before DOCTYPE system identifier state.

	U+0022 QUOTATION MARK (")
	; This is a missing-whitespace-after-doctype-system-keyword parse error. Set the current DOCTYPE token's system identifier to the empty string (not missing), then switch to the DOCTYPE system identifier (double-quoted) state.

	U+0027 APOSTROPHE (')
	; This is a missing-whitespace-after-doctype-system-keyword parse error. Set the current DOCTYPE token's system identifier to the empty string (not missing), then switch to the DOCTYPE system identifier (single-quoted) state.

	U+003E GREATER-THAN SIGN (>)
	; This is a missing-doctype-system-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit the current DOCTYPE token.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; This is a missing-quote-before-doctype-system-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Reconsume in the bogus DOCTYPE state.

end state


state	13.2.5.64 Before DOCTYPE system identifier state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Ignore the character.

	U+0022 QUOTATION MARK (")
	; Set the current DOCTYPE token's system identifier to the empty string (not missing), then switch to the DOCTYPE system identifier (double-quoted) state.

	U+0027 APOSTROPHE (')
	; Set the current DOCTYPE token's system identifier to the empty string (not missing), then switch to the DOCTYPE system identifier (single-quoted) state.

	U+003E GREATER-THAN SIGN (>)
	; This is a missing-doctype-system-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit the current DOCTYPE token.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; This is a missing-quote-before-doctype-system-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Reconsume in the bogus DOCTYPE state.

end state


state	13.2.5.65 DOCTYPE system identifier (double-quoted) state
; Consume the next input character:

	U+0022 QUOTATION MARK (")
	; Switch to the after DOCTYPE system identifier state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current DOCTYPE token's system identifier.

	U+003E GREATER-THAN SIGN (>)
	; This is an abrupt-doctype-system-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit the current DOCTYPE token.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; Append the current input character to the current DOCTYPE token's system identifier.

end state


state	13.2.5.66 DOCTYPE system identifier (single-quoted) state
; Consume the next input character:

	U+0027 APOSTROPHE (')
	; Switch to the after DOCTYPE system identifier state.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current DOCTYPE token's system identifier.

	U+003E GREATER-THAN SIGN (>)
	; This is an abrupt-doctype-system-identifier parse error. Set the current DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit the current DOCTYPE token.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; Append the current input character to the current DOCTYPE token's system identifier.

end state


state	13.2.5.67 After DOCTYPE system identifier state
; Consume the next input character:

	U+0009 CHARACTER TABULATION (tab)
	U+000A LINE FEED (LF)
	U+000C FORM FEED (FF)
	U+0020 SPACE
	; Ignore the character.

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state. Emit the current DOCTYPE token.

	EOF
	; This is an eof-in-doctype parse error. Set the current DOCTYPE token's force-quirks flag to on. Emit the current DOCTYPE token. Emit an end-of-file token.

	Anything else
	; This is an unexpected-character-after-doctype-system-identifier parse error. Reconsume in the bogus DOCTYPE state. (This does not set the current DOCTYPE token's force-quirks flag to on.)

end state


state	13.2.5.68 Bogus DOCTYPE state
; Consume the next input character:

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state. Emit the DOCTYPE token.

	U+0000 NULL
	; This is an unexpected-null-character parse error. Ignore the character.

	EOF
	; Emit the DOCTYPE token. Emit an end-of-file token.

	Anything else
	; Ignore the character.

end state


state	13.2.5.69 CDATA section state
; Consume the next input character:

	U+005D RIGHT SQUARE BRACKET (])
	; Switch to the CDATA section bracket state.

	EOF
	; This is an eof-in-cdata parse error. Emit an end-of-file token.

	Anything else
	; Emit the current input character as a character token.

; Note: U+0000 NULL characters are handled in the tree construction stage, as part of the in foreign content insertion mode, which is the only place where CDATA sections can appear.

end state


state	13.2.5.70 CDATA section bracket state
; Consume the next input character:

	U+005D RIGHT SQUARE BRACKET (])
	; Switch to the CDATA section end state.

	Anything else
	; Emit a U+005D RIGHT SQUARE BRACKET character token. Reconsume in the CDATA section state.

end state


state	13.2.5.71 CDATA section end state
; Consume the next input character:

	U+005D RIGHT SQUARE BRACKET (])
	; Emit a U+005D RIGHT SQUARE BRACKET character token.

	U+003E GREATER-THAN SIGN (>)
	; Switch to the data state.

	Anything else
	; Emit two U+005D RIGHT SQUARE BRACKET character tokens. Reconsume in the CDATA section state.

end state


state	13.2.5.72 Character reference state
; Set the temporary buffer to the empty string. Append a U+0026 AMPERSAND (&) character to the temporary buffer. Consume the next input character:

	ASCII alphanumeric
	; Reconsume in the named character reference state.

	U+0023 NUMBER SIGN (#)
	; Append the current input character to the temporary buffer. Switch to the numeric character reference state.

	Anything else
	; Flush code points consumed as a character reference. Reconsume in the return state.

end state


;state	13.2.5.73 Named character reference state
; Consume the maximum number of characters possible, where the consumed characters are one of the identifiers in the first column of the named character references table. Append each character to the temporary buffer when it's consumed.
;
; If there is a match:
;	If the character reference was consumed as part of an attribute, and the last character matched is not a U+003B SEMICOLON character (;), and the next input character is either a U+003D EQUALS SIGN character (=) or an ASCII alphanumeric, then, for historical reasons, flush code points consumed as a character reference and switch to the return state.
;
;	Otherwise:
;		1. If the last character matched is not a U+003B SEMICOLON character (;), then this is a missing-semicolon-after-character-reference parse error.
;		2. Set the temporary buffer to the empty string. Append one or two characters corresponding to the character reference name (as given by the second column of the named character references table) to the temporary buffer.
;		3. Flush code points consumed as a character reference. Switch to the return state.
;
; Otherwise: Flush code points consumed as a character reference. Switch to the ambiguous ampersand state.
;
; Example: If the markup contains (not in an attribute) the string I'm &notit; I tell you, the character reference is parsed as "not", as in, I'm ¬it; I tell you (and this is a parse error). But if the markup was I'm &notin; I tell you, the character reference would be parsed as "notin;", resulting in I'm ∉ I tell you (and no parse error).
;
; However, if the markup contains the string I'm &notit; I tell you in an attribute, no character reference is parsed and string remains intact (and there is no parse error).
;
;end state


state	13.2.5.74 Ambiguous ampersand state
; Consume the next input character:

	ASCII alphanumeric
	; If the character reference was consumed as part of an attribute, then append the current input character to the current attribute's value. Otherwise, emit the current input character as a character token.

	U+003B SEMICOLON (;)
	; This is an unknown-named-character-reference parse error. Reconsume in the return state.

	Anything else
	; Reconsume in the return state.

end state


state	13.2.5.75 Numeric character reference state
; Set the character reference code to zero (0).

; Consume the next input character:

	U+0078 LATIN SMALL LETTER X
	U+0058 LATIN CAPITAL LETTER X
	; Append the current input character to the temporary buffer. Switch to the hexadecimal character reference start state.

	Anything else
	; Reconsume in the decimal character reference start state.

end state


state	13.2.5.76 Hexadecimal character reference start state
; Consume the next input character:

	ASCII hex digit
	; Reconsume in the hexadecimal character reference state.

	Anything else
	; This is an absence-of-digits-in-numeric-character-reference parse error. Flush code points consumed as a character reference. Reconsume in the return state.

end state


state	13.2.5.77 Decimal character reference start state
; Consume the next input character:

	ASCII digit
	; Reconsume in the decimal character reference state.

	Anything else
	; This is an absence-of-digits-in-numeric-character-reference parse error. Flush code points consumed as a character reference. Reconsume in the return state.

end state


state	13.2.5.78 Hexadecimal character reference state
; Consume the next input character:

	ASCII digit
	; Multiply the character reference code by 16. Add a numeric version of the current input character (subtract 0x0030 from the character's code point) to the character reference code.

	ASCII upper hex digit
	; Multiply the character reference code by 16. Add a numeric version of the current input character as a hexadecimal digit (subtract 0x0037 from the character's code point) to the character reference code.

	ASCII lower hex digit
	; Multiply the character reference code by 16. Add a numeric version of the current input character as a hexadecimal digit (subtract 0x0057 from the character's code point) to the character reference code.

	U+003B SEMICOLON (;)
	; Switch to the numeric character reference end state.

	Anything else
	; This is a missing-semicolon-after-character-reference parse error. Reconsume in the numeric character reference end state.

end state


state	13.2.5.79 Decimal character reference state
; Consume the next input character:

	ASCII digit
	; Multiply the character reference code by 10. Add a numeric version of the current input character (subtract 0x0030 from the character's code point) to the character reference code.

	U+003B SEMICOLON (;)
	; Switch to the numeric character reference end state.

	Anything else
	; This is a missing-semicolon-after-character-reference parse error. Reconsume in the numeric character reference end state.

end state


;state	13.2.5.80 Numeric character reference end state
; Check the character reference code:

; If the number is 0x00, then this is a null-character-reference parse error. Set the character reference code to 0xFFFD.

; If the number is greater than 0x10FFFF, then this is a character-reference-outside-unicode-range parse error. Set the character reference code to 0xFFFD.

; If the number is a surrogate, then this is a surrogate-character-reference parse error. Set the character reference code to 0xFFFD.

; If the number is a noncharacter, then this is a noncharacter-character-reference parse error.

; If the number is 0x0D, or a control that's not ASCII whitespace, then this is a control-character-reference parse error. If the number is one of the numbers in the first column of the following table, then find the row with that number in the first column, and set the character reference code to the number in the second column of that row.

;	Number	| Code point
;	0x80	| 0x20AC	EURO SIGN (€)
;	0x82	| 0x201A	SINGLE LOW-9 QUOTATION MARK (‚)
;	0x83	| 0x0192	LATIN SMALL LETTER F WITH HOOK (ƒ)
;	0x84	| 0x201E	DOUBLE LOW-9 QUOTATION MARK („)
;	0x85	| 0x2026	HORIZONTAL ELLIPSIS (…)
;	0x86	| 0x2020	DAGGER (†)
;	0x87	| 0x2021	DOUBLE DAGGER (‡)
;	0x88	| 0x02C6	MODIFIER LETTER CIRCUMFLEX ACCENT (ˆ)
;	0x89	| 0x2030	PER MILLE SIGN (‰)
;	0x8A	| 0x0160	LATIN CAPITAL LETTER S WITH CARON (Š)
;	0x8B	| 0x2039	SINGLE LEFT-POINTING ANGLE QUOTATION MARK (‹)
;	0x8C	| 0x0152	LATIN CAPITAL LIGATURE OE (Œ)
;	0x8E	| 0x017D	LATIN CAPITAL LETTER Z WITH CARON (Ž)
;	0x91	| 0x2018	LEFT SINGLE QUOTATION MARK (‘)
;	0x92	| 0x2019	RIGHT SINGLE QUOTATION MARK (’)
;	0x93	| 0x201C	LEFT DOUBLE QUOTATION MARK (“)
;	0x94	| 0x201D	RIGHT DOUBLE QUOTATION MARK (”)
;	0x95	| 0x2022	BULLET (•)
;	0x96	| 0x2013	EN DASH (–)
;	0x97	| 0x2014	EM DASH (—)
;	0x98	| 0x02DC	SMALL TILDE (˜)
;	0x99	| 0x2122	TRADE MARK SIGN (™)
;	0x9A	| 0x0161	LATIN SMALL LETTER S WITH CARON (š)
;	0x9B	| 0x203A	SINGLE RIGHT-POINTING ANGLE QUOTATION MARK (›)
;	0x9C	| 0x0153	LATIN SMALL LIGATURE OE (œ)
;	0x9E	| 0x017E	LATIN SMALL LETTER Z WITH CARON (ž)
;	0x9F	| 0x0178	LATIN CAPITAL LETTER Y WITH DIAERESIS (Ÿ)
;
; Set the temporary buffer to the empty string. Append a code point equal to the character reference code to the temporary buffer. Flush code points consumed as a character reference. Switch to the return state.
;
;end state
