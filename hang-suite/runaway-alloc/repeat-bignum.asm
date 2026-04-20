; Category: runaway allocation (both axes)
; Mechanism: fasmg uses arbitrary-precision integers everywhere,
; including the `repeat` count. There is no fixed upper bound on
; the iteration count -- a count of 2^128 is parsed and iterated
; just like any other number. The only termination is the loop
; actually running through every iteration, or the body hitting
; `break`.
; Body emits one byte per iteration, so time AND memory are both
; effectively unbounded.
; Expected: never terminates in any reasonable wall clock.
; Mitigation today: none at the core level.

repeat (1 shl 128)
  db 0
end repeat
