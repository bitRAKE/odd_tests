; Category: runaway allocation
; Mechanism: each macro calls the one below it twice. Depth N ->
; 2^N body expansions. 20 levels = 1M, 25 = 32M, 30 = 1 G.
; Expected: exponential expansion time AND memory.
; Why it's interesting: the iteration count here is invisible in
; the source -- no literal giant number. Hard to spot in review.
; Mitigation today: `maximum_depth_of_stack` caps the recursion,
; but at DEPTH 10000 we've long since produced 2^N bytes.

macro level0
  db 0
end macro

macro level1
  level0
  level0
end macro

macro level2
  level1
  level1
end macro

macro level3
  level2
  level2
end macro

macro level4
  level3
  level3
end macro

macro level5
  level4
  level4
end macro

; 2^5 = 32 bytes. Bump this by adding more levels to see the blow-up.
level5
