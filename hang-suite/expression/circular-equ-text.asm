; Category: expression-level runaway
; Mechanism: text-substitution `equ` pointing at each other. Each
; use expands once; with cycle, could in principle spin -- unless
; fasmg's equ is single-level by design.
; Expected: likely works or errors cleanly; included to verify.

a equ b
b equ a

db a
