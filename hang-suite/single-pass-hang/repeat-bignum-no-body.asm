; Category: single-pass hang (time axis only; memory bounded)
; Mechanism: bignum `repeat` count with a body that does no
; allocating or emitting. Time is unbounded (the interpreter
; dutifully works through each iteration); memory is flat.
; Distinguishes from `repeat-bignum.asm` which also blows memory.
; Expected: CPU-pegged forever, no heap growth, no output.
; Mitigation today: none at the core level.

repeat (1 shl 128)
  if 0
    db 0
  end if
end repeat
