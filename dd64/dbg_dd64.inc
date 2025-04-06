define __x64dbg? __x64dbg
namespace __x64dbg

	virtual at 0
		HexDigits:: db '0123456789ABCDEF'
	end virtual

	collected_source = ''
	collected_$ = $
	collected_$% = $%
	collected_$%% = $%%

	k = 1 + ((bsr __source__) shr 3)
	tmp = __source__ bswap k
	; assume source file name has an extension, remove it:
	while 1
		if '.' = (tmp and 0xFF)
			break
		end if
		tmp = tmp shr 8
	end while
	; how many bytes in file name:
	k = 0
	while 1
		k = k + 8
		b = ((tmp shr k) and 0xFF)
		if b = '/'
			break
		else if b = '\'
			break
		else if b = 0
			break
		end if
	end while
	; prune path, append new extension:
	tmp = ((((1 shl k)-1) and tmp) shl 24) + 'exe'
	k = 1 + ((bsr __source__) shr 3)
	__MODULE_NAME__ = string (tmp bswap k)

	calminstruction generate
		local	source, $, $%, $%%

	    reverse:
		take	source, collected_source
		take	$, collected_$
		take	$%, collected_$%
		take	$%%, collected_$%%
		jyes	reverse

		local	offset
		compute offset, $%

	    main:
		take	, $%
		take	, $%%
		take	$%, $%
		jno	done

		check	source
		jno	next

		local	undefined_bytes, defined_bytes
		compute undefined_bytes, $% - $%%
		compute defined_bytes, $%% - offset
		compute offset, $%

		check	defined_bytes
		jno	next
		check	($ - PE.IMAGE_BASE) >= 0
		jno	next

		local	counter, digit

		asm db 9,9,'{',10
		asm db 9,9,9,'"module": "',__MODULE_NAME__,'",',10
		asm db 9,9,9,'"address": "0x'

		; offset must be in hexadecimal
		compute counter, 8
	    print_offset:
		compute counter, counter - 1
		compute digit, (($ - PE.IMAGE_BASE) shr (counter shl 2)) and 0Fh
		asm load digit:1 from HexDigits:digit
		asm db digit
		check counter
		jyes print_offset

		asm db '",',10
;		asm db 9,9,9,'"manual": true,',10
		asm db 9,9,9,'"text": "',source,'"',10
		asm db 9,9,'},',10

	    next:
		take	, source
		take	, $
		jump	main
	    done:
	end calminstruction ; generate
end namespace ; __x64dbg

postpone ?
	purge ?
;	virtual as 'dd32' ; todo: output mode detection
	virtual as 'dd64'
		db '{',10
		; create comments of source text
		db 9,'"comments": [',10
		__x64dbg.generate
		; clear trailing comma
		store ' ':1 at $-2
		db 9,'],',10
		db 9,'"hash": "0"',10
		db '}',10
	end virtual
end postpone

calminstruction restartout? origin
	arrange origin,=restartout origin
	assemble origin
    reset:
	take ,__x64dbg.collected_source
	take ,__x64dbg.collected_$
	take ,__x64dbg.collected_$%
	take ,__x64dbg.collected_$%%
	jyes reset
end calminstruction

calminstruction ? line&
	local tmp
	arrange tmp,line
	stringify tmp
	take __x64dbg.collected_source,tmp
	compute tmp,$ scale 0
	take __x64dbg.collected_$,tmp
	compute tmp,$%
	take __x64dbg.collected_$%,tmp
	compute tmp,$%%
	take __x64dbg.collected_$%%,tmp
	assemble line
end calminstruction
