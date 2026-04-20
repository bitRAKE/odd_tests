; Category: POSITIVE CONTROL (virtual-block variant)
; Same spirit as petabyte-virtual.asm, but using `virtual ... end
; virtual` blocks instead of `section`. Each virtual block is its
; own address space; labels defined inside are relative to it, and
; `sizeof` retrieves the block's total size (including reserved
; `rb` bytes).
;
; What this does:
;   - 2^N iterations, each defining a `virtual` block containing
;     a 4-byte literal and a 1 GB reserved region
;   - second pass walks the labels and sums sizeof of each block
;   - third repeat displays the summed virtual-byte count
;
; Observed scaling (user-provided data, on author's hardware):
;   N    seconds    delta (s)
;   19    1.6        --
;   20    3.4       1.8
;   21    7.2       3.8
;   22   17.2      10.0
;   23   46.9      29.7
;   24  140.5      93.6
;
; Notes on the scaling: doubling N doubles the iteration count but
; also doubles the number of labels looked up by the second loop,
; so per-level cost grows faster than linearly. 2^24 labels is
; around 17 million symbol-table entries, and per-iteration
; sizeof-lookup is not O(1).
;
; For N = 24 the total virtual bytes tallies to
; 18014398576590848 = 2^24 * (2^30 + 4) ~= 16 EiB. The output
; file is still 0 bytes -- no `dd` data is kept; the literals are
; inside `virtual` blocks which never contribute to output.
;
; A proposed wall-clock guard would need its ceiling set above
; 150 seconds to avoid killing this at N=24. That's a legitimate
; workload; the guard default should be "off" and any opt-in
; should be per-job, not global.

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
