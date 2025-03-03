
; light state machine framework
;	+ generate complex labeling based on complex state name
;	+ U+XXXX code-point labeling of local transitions
;	+ various more complex transition based on byte groups or global state
;		- EOF			<global code-point reader state>
;		- Anything else		<all non-defined transitions: code-point or other>
;		- ASCII alphanumeric	[0-9A-Za-z]
;		- ASCII alpha		[A-Za-z]
;		- ASCII upper alpha	[A-Z]
;		- ASCII lower alpha	[a-z]
;		- ASCII digit		[0-9]
;		- ASCII hex digit	[0-9A-Fa-f]
;		- ASCII upper hex digit	[A-F]
;		- ASCII lower hex digit	[a-f]


;	+ rely on fasmg name collision to detect duplicates (need reverse lookup tool)
;	+ namespace wrapper allows several types of optimization using symbolic refereneces, but ditches the use bitmap - which means table generation requires brute-force discovery for ASCII range. Non-character states should use a vector for discovery: allowing as many pseudo-states as needed.
;

macro state? anchor*&
	; create a unique name - to prefix cases - based on anchor value
	repeat 1,N:`anchor
		;display `anchor,10
		namespace ?N
	end repeat

	macro state_range min*,max*
		repeat 1+max-min, i:min
			?i:
		end repeat
	end macro

	; virtual redirector: symbol cases are defined as another namespace reference
	; (should only impact table generation, eliminates case JMPs)
	macro reroute? space*,ref
		err 'not implemented'
		match ,ref
			; hard reroute - outside state space
		else
			; todo: resolve namespace reference
		end if
		calminstruction ? line&
			match =end? =reroute?,line
			jyes done
			; todo: detect case references
			asm	define case route
			exit
		; verify no difference in $
		done:	arrange line, =purge ?
			assemble line
		end calminstruction
	end macro

	calminstruction ? line&
		match =end? =state?,line
		jyes done
		match =EOF,line
		jyes eof
		match =Anything =else,line
		jyes any

		local group,CODE,NAME,var,val
		match =ASCII group,line
		jyes grp

		match =U=+CODE NAME,line
		jyes new

	unk:	; pass unknowns to assembly process
		assemble line
		exit

	grp:	match =alphanumeric,group
		jyes alnum
		match =alpha,group
		jyes alpha
		match =upper =alpha,group
		jyes upper
		match =lower =alpha,group
		jyes lower

		match =digit,group
		jyes digit
		match =hex =digit,group
		jyes hex
		match =upper =hex =digit,group
		jyes hup
		match =lower =hex =digit,group
		jyes hlow
		jump unk

	alnum:	asm	state_range '0','9'
	alpha:	asm	state_range 'a','z'
	upper:	asm	state_range 'A','Z'
		exit

	lower:	asm	state_range 'a','z'
		exit

	digit:	asm	state_range '0','9'
		exit

	hex:	asm	state_range '0','9'
		asm	state_range 'a','f'
	hup:	asm	state_range 'A','F'
		exit

	hlow:	asm	state_range 'a','f'
		exit

	new:	arrange var,0x#CODE ; process CODE as hexadecimal
		compute val,var

		arrange var,?val:
		assemble var
		exit

	eof:	arrange var,=EOF:
		assemble var
		exit

	any:	arrange var,=ANY:
		assemble var
		exit

	; Note: State constraints should be resolved at table generation.

	done:	arrange line, =purge ?,=state_range,=reroute
		assemble line
		arrange line, =end =namespace
		assemble line
	end calminstruction
end macro
