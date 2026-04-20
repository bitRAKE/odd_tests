; Category: single-pass hang
; Mechanism: `while 1` with a per-iteration side effect (`db`), so
; the output area grows without bound as the loop spins. Demonstrates
; that runaway output and runaway time compound.
; Expected: grows output, eventually OOMs (or user kills it first).
; Mitigation today: none at the core level.

while 1
  db 0
end while
