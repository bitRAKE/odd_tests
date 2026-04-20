; Category: POSITIVE CONTROL
; Idiomatic fasmg usage that MUST pass without being caught by any
; proposed runaway guard. This file's role in the suite is to
; force guard proposals to articulate the difference between
; "legitimate bignum arithmetic + virtual-address reasoning" and
; "runaway time / memory."
;
; What this does:
;   - 2^20 = ~1M iterations of `repeat`
;   - each iteration: 4 bytes of literal data, 1 GB of reserved
;     (`rb`) virtual space, then `section` to a new address area
;   - total literal bytes tallied as bignum: 4 MB
;   - total virtual bytes tallied as bignum: 2^50 = 1 PB
;   - `restartout` at the end throws away the 4 MB of literal
;     data; the final output file is 0 bytes
;
; Observed: ~1.7 s on a modern CPU, 0-byte output file,
; displays "4194304 literal bytes" and "1125899906842624 virtual
; bytes" (i.e. 4 MiB and 1 PiB).
;
; Why it matters:
;   - The bignum counts (both iteration count and byte tallies) are
;     fine -- the core reasons about petabyte-scale layouts using
;     arbitrary-precision integers.
;   - The 1 PB of virtual `rb` is never committed memory; `section`
;     plus `rb` is purely an address-space abstraction.
;   - `restartout` demonstrates that bytes-emitted-during-
;     assembly is NOT the same as bytes-in-the-output-file.
;
; Any guard that treats "sum of `rb` counts" or "sum of emitted
; bytes" as the output-size metric would wrongly flag this. The
; correct metric is bytes that would actually be written by
; `write_output_file` at assembly end.

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
