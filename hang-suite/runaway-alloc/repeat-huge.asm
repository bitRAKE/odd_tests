; Category: runaway allocation
; Mechanism: explicit huge iteration count with a body that emits
; one byte per iteration. 1 G * 1 byte = 1 GB output.
; Expected: slow, eats ~1 GB, eventually completes or OOMs.
; Mitigation today: none at the core level. Caller's VirtualAlloc
; eventually fails, fasmg core's `out_of_memory` path fires, exits.

repeat 1000000000
  db 0
end repeat
