; Category: expression-level runaway
; Mechanism: two `=` (numeric) constants that reference each other.
; When an expression evaluator needs `a`'s value it looks up `b`,
; which looks up `a`, which... does fasmg detect this or spin?
; Expected: fasmg reports an error about undefined/unresolvable
; symbol during assembly, not a hang. `equ` (text) would textually
; substitute and eventually exhaust a buffer.
; This test: numeric `=` form, then use.

a = b
b = a

; Force evaluation:
db a
