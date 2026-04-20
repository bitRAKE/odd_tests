; Category: single-pass hang
; Mechanism: macro calls itself. Caught by maximum_depth_of_stack
; (default 10000) per the survey -- verify this actually triggers
; vs. hanging indefinitely or blowing host stack.
; Expected: "stack limit exceeded" error after ~10000 nested
; expansions, not a hang.
; Note: fasmg expands macros at call time, so this recurses into
; the directives stack rather than the host CPU stack.

macro spin
  spin
end macro

spin
