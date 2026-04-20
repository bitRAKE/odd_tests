; Category: CALM runtime runaway
; Mechanism: a CALM (Calm Assembly Language Macros) instruction
; that invokes itself. CALM is Turing-complete and the interpreter
; at source/calm.inc has no instruction-count ceiling per the
; survey -- a jump-to-self runs forever in one pass.
; Expected: hangs until max_stack_depth hits (if expansion uses the
; directives stack) OR forever (if it's a tight CALM loop inside
; one call).
; Mitigation today: none at the core.

calminstruction spin
  spin
end calminstruction

spin
