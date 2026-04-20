; Category: reserved-bytes runaway
; Mechanism: `rb N` reserves N bytes of uninitialized output.
; fasmg tracks this in the area structures; for sufficiently large
; N the internal bookkeeping itself may allocate heap, and the
; caller receiving the output sees an N-byte region.
; Expected: succeeds quickly (no zero-filling work), but the
; output artifact is 4 GB on disk. Worth observing because it
; shows that allocation-related runaway doesn't require time to
; happen -- a single directive can commit arbitrarily-sized output.

rb 0xFFFFFFFF
