; Category: include cycle
; Mechanism: a includes b, b includes a. fasmg doesn't detect the
; cycle; it recurses until maximum_depth_of_stack (default 10000)
; fires. Prior to hitting that limit, every file is re-opened and
; re-read -- 10000 reads of each file.
; Expected: "stack limit exceeded" after ~10k nested includes.
; Mitigation today: max_stack_depth catches it eventually.
; Note: invoke with `fasmg a.asm`.

include 'b.asm'
