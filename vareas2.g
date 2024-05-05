dynamic_size = 0
postpone
	set_size := dynamic_size
	repeat 1,S:set_size
		display `S,' total bytes'
	end repeat
	rb set_size
end postpone

; dynamic use of reserved space

virtual at 0
var:: file 'vareas2.g'
end virtual

repeat sizeof var
	load char:1 from var:%-1
	dynamic_size = dynamic_size + char
end repeat
