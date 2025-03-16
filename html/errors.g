
; see: https://html.spec.whatwg.org/multipage/parsing.html#parse-errors

define ERROR ERROR ; circular base

iterate name,\; unique parser errors
	abrupt-closing-of-empty-comment,\
	abrupt-doctype-public-identifier,\
	abrupt-doctype-system-identifier,\
	absence-of-digits-in-numeric-character-reference,\
	cdata-in-html-content,\
	character-reference-outside-unicode-range,\
	control-character-in-input-stream,\
	control-character-reference,\
	duplicate-attribute,\
	end-tag-with-attributes,\
	end-tag-with-trailing-solidus,\
	eof-before-tag-name,\
	eof-in-cdata,\
	eof-in-comment,\
	eof-in-doctype,\
	eof-in-script-html-comment-like-text,\
	eof-in-tag,\
	incorrectly-closed-comment,\
	incorrectly-opened-comment,\
	invalid-character-sequence-after-doctype-name,\
	invalid-first-character-of-tag-name,\
	missing-attribute-value,\
	missing-doctype-name,\
	missing-doctype-public-identifier,\
	missing-doctype-system-identifier,\
	missing-end-tag-name,\
	missing-quote-before-doctype-public-identifier,\
	missing-quote-before-doctype-system-identifier,\
	missing-semicolon-after-character-reference,\
	missing-whitespace-after-doctype-public-keyword,\
	missing-whitespace-after-doctype-system-keyword,\
	missing-whitespace-before-doctype-name,\
	missing-whitespace-between-attributes,\
	missing-whitespace-between-doctype-public-and-system-identifiers,\
	nested-comment,\
	noncharacter-character-reference,\
	noncharacter-in-input-stream,\
	non-void-html-element-start-tag-with-trailing-solidus,\
	null-character-reference,\
	surrogate-character-reference,\
	surrogate-in-input-stream,\
	unexpected-character-after-doctype-system-identifier,\
	unexpected-character-in-attribute-name,\
	unexpected-character-in-unquoted-attribute-value,\
	unexpected-equals-sign-before-attribute-name,\
	unexpected-null-character,\
	unexpected-question-mark-instead-of-tag-name,\
	unexpected-solidus-in-tag,\
	unknown-named-character-reference

	; array vector, iterator
	define ERRORS name
	repeat 1,N:`name,V:%
		; forward lookup, name -> index
		ERROR.N := V
	end repeat
	; reverse lookup, index -> name
	define ERROR.% name
end iterate

; accessing ERROR referrence(s):
;
;	irpv ERRORS
;
;	db ERROR.N ; use index of error
;
;	if defined ERROR.N ; assembler will error on undefined names

; Note: Brief error messages in some language lack punctuation.

; Language file reader links text message to error index.

calminstruction error_reader line&
	local count,var,val
	init count

	match =mvmacro? =error_reader =, =?,line
	jno go
	assemble line
	exit

go:	compute count,1+count
	stringify line
	check 1 and count
	jno get

	compute val,0+line
	arrange var,=ERROR.val
	check defined var
	jyes good

	err line bappend ' not an expected ERROR name'
	exit

get:	publish var:,line
	exit

good:	compute val,var
	arrange var,=ERROR.val.=MESSAGE
end calminstruction

; testing ...

define LANG 'cn'

include 'errors.' bappend LANG bappend '.txt',\
	mvmacro ?,error_reader
	mvmacro error_reader,?

irpv _, ERRORS
	; Note: This will error if a definition is missing.
	; UTF-8 strings will might need conversion.
	display `_,' is defined as "',ERROR.%.MESSAGE,'"',10
end irpv
