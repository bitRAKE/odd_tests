N := 20
lbytes = 0
vbytes = 0
repeat 1 shl N ; could use $$ instead of A#%, throughout
	A#%:
	dd %			; literal data
	rb 1 shl 30		; virtual data

	lbytes = lbytes + $%% - A#%
	vbytes = vbytes + $ - A#% - 4
	section $%% ; new address area
end repeat

repeat 1,L:lbytes,V:vbytes
	display `L,' literal bytes',10
	display `V,' virtual bytes'
end repeat
restartout ; don't write data
