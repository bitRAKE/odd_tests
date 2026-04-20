; Category: single-pass hang
; Mechanism: `while 1` with a truthy condition that never flips.
; Expected: hangs forever in one pass. No core guard catches this.
; Mitigation today: caller-side wall-clock timeout; kill process.

while 1
end while
