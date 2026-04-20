; Category: runaway allocation via nesting
; Mechanism: nested `repeat` blocks multiply. 10000 * 10000 = 100M
; iterations, each emitting a byte -> 100 MB output. The literal
; counts are visible here, but real-world cases hide them in named
; constants or expressions.
; Expected: succeeds, slowly, with 100 MB of output. Valuable as
; a calibration point: "what's my wall-clock cost per MB at this
; host speed?" A hanged test that's really just slow looks
; identical to a true hang from outside.

repeat 10000
  repeat 10000
    db 0
  end repeat
end repeat
