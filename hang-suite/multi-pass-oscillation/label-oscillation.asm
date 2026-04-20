; Category: multi-pass oscillation
; Mechanism: a symbol's value depends on whether it already exists,
; so pass N disagrees with pass N-1 forever. fasmg re-passes as long
; as anything changes; the pass budget (default 100) eventually
; catches this, but we've burned 100 full passes first.
; Expected: "code cannot be generated" after maximum_number_of_passes.
; Mitigation today: pass limit catches it. Lower the -p limit if
; you want faster failure.

if defined lbl
  lbl = lbl + 1
else
  lbl = 0
end if
