; Category: CALM internal loop
; Mechanism: CALM's `jump` opcode inside a single calminstruction,
; without re-entering it. This is a tight interpreter loop in
; source/calm.inc:1918-2100 -- no max_stack_depth interaction,
; no directive-stack growth, just a CPU-level infinite loop
; inside the VM.
; Expected: hangs hard; no core-side guard.

calminstruction spin
    again:
    jump again
end calminstruction

spin
