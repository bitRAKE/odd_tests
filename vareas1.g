N := 20
repeat 1 shl N
	virtual at 0
	A#%::
		dd %
		rb 1 shl 30
	end virtual
end repeat

vbytes = 0
repeat 1 shl N
	vbytes = vbytes + sizeof A#%
end repeat

repeat 1,V:vbytes
	display `V,' virtual bytes'
end repeat

;	flat assembler  version g.kd3c
;	18014398576590848 virtual bytes
;	1 pass, 140.5 seconds, 0 bytes.

; exponent	seconds		delta
;	24	140.5		93.6
;	23	46.9		29.7
;	22	17.2		10.0
;	21	7.2		3.8
;	20	3.4		1.8
;	19	1.6
