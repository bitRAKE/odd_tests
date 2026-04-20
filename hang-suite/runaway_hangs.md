# fasmg hangs and runaway allocations — research + proposals

## Executive summary

fasmg's core has three built-in resource guards — pass count, error
count, stack depth — each aimed at a specific class of degenerate
input. None of the three detects or bounds **wall-clock time**
or **committed output size**. In practice this means certain
source inputs (malicious, buggy, or merely careless) can make
fasmg consume arbitrary resources without any core-side
termination signal.

Equally important: fasmg uses arbitrary-precision integers
*everywhere*. Iteration counts, address tallies, section sizes —
all bignum. This enables legitimate workloads that look
astronomical: a `repeat 2^20` that tallies a petabyte of virtual
address space and produces a 0-byte output file in under two
seconds is idiomatic fasmg. Any guard proposal has to distinguish
"petabyte of virtual bignum arithmetic" from "petabyte of disk
writes." Those are not the same thing and the core treats them as
such.

This doc surveys the runaway vectors concretely, backs them with
a runnable example suite at [examples/hang-suite/](../../examples/hang-suite/)
that includes positive controls, and proposes two core-side
guards that close the practical gaps without touching the design.

## Two independent axes

Every runaway in fasmg sits on one or both of these axes.

**Time axis.** How long does the assembly take to complete (or
decide it can't)? Unbounded vectors: `while 1`, `repeat BIGINT`
with any non-breaking body, CALM with an unconditional backward
`jump`. The pass budget (`maximum_number_of_passes`, default
100) only counts **complete passes**; a single-pass runaway
doesn't count against it.

**Memory axis.** Does assembly accumulate state without bound?
Unbounded vectors: `db` / `dw` / `dd` inside a large loop,
exponential macro expansion, `rb N` with large N as interpreted
by the output format.

These axes are independent. `while 1` with an empty body is
time-unbounded / memory-bounded. `rb (1 shl 32)` is
time-bounded / memory-possibly-unbounded-later. `repeat 2^32 {
db 0 }` is both. Any guard proposal has to pick its axis; a cap
that conflates them (like "iteration count") is awkward because
legitimate workloads on one axis can look pathological on the
other.

## Bignum everywhere

This is the single most important fact about fasmg's runaway
story. Integer operands are arbitrary-precision; the core reasons
about `2^128`-scale counts and addresses as naturally as it
reasons about `42`.

Concrete evidence from probes against the shipping binary:

```
; parses and iterates dutifully; body breaks out early
repeat (1 shl 128)
  break
end repeat                                        ; 1 pass, OK

; counter variable tracks a bignum; this test spins toward a
; 2^64-sized sentinel and never reaches it in any reasonable time
repeat 0x1_0000_0000_0000_0001, i:0
  if i = 0x1_0000_0000_0000_0000
    dq i
    break
  end if
end repeat                                        ; effectively infinite
```

Implications for any runaway proposal:

1. **There is no "counter ceiling" to rely on.** A guard that
   depends on "the count can't exceed 2^N" is fiction. The count
   is as big as the source can express, which is arbitrarily big.
2. **Asking "is the count too large?" is the wrong question.**
   The example suite's `positive-control/` subdir shows
   `repeat 2^20` as idiomatic; bumping N to 25 or 30 is still
   legitimate in the same style.
3. **The right questions are on the time and memory axes
   independently:** how long has the assembly been running, and
   how many bytes would be written to disk if it stopped now?
   Both are measurable; neither requires any assumption about
   counter representation.

## Virtual vs committed output

fasmg's output model is layered:

- **Emitted bytes.** Any `db` / `dw` / `dd` / `rb` contributes to
  an output area.
- **Sections / virtual blocks.** `section` begins a new address
  space; `virtual ... end virtual` is a scoped one. Bytes inside
  a virtual block never contribute to the file output. Bytes
  inside a section do, but `restartout` can discard them.
- **File bytes.** What `write_output_file` would write at the
  end of assembly: the current state of the output area(s)
  after the last `restartout`, stripped of virtual reservations.

A source can legitimately emit trillions of virtual bytes through
section / virtual block constructs and still write a 0-byte file:

```fasmg
N := 20
repeat 1 shl N
    virtual at 0
    A#%::
        dd %
        rb 1 shl 30
    end virtual
end repeat
```

The observed tally is 2^24 × (2^30 + 4) ≈ 16 EiB virtual. Output
file: 0 bytes. Wall-clock at N=20: ~1.7 s. At N=24: ~140 s.

This matters for proposal design: **a guard that triggers on
"total bytes emitted through `db` / `rb`" would kill every
legitimate petabyte-scale layout computation**. The correct
metric, if we must pick one, is the file bytes — the output
that survives virtual blocks, section partitioning, and
`restartout`.

## What the core guards today

| guard | default | axis | scope | caught class |
|---|---|---|---|---|
| `maximum_number_of_passes` | 100 | both (indirectly) | multi-pass convergence | oscillating labels, undefined references that can't resolve |
| `maximum_number_of_errors` | 1000 | — | per-assembly | error flooding (but does *not* stop assembly — just suppresses messages after the cap) |
| `maximum_depth_of_stack`   | 10 000 | memory-ish | directive stack (includes, macro expansion, `repeat`/`while` bodies) | recursive macros, mutual includes, runaway nesting |

All three are caller-configurable via `-p`, `-e`, `-r`. Lowering
them catches pathological inputs faster at the cost of rejecting
unusually-deep legitimate sources.

## What the core doesn't guard

| vector | guard today | axis | example |
|---|---|---|---|
| wall-clock time | none | time | `while 1`, CALM `jump`, `repeat BIGINT` with any body |
| committed output file size | none | memory | large `repeat` + `db` without `restartout` |
| reserved output (`rb`) size | none | memory-deferred | `rb 0xFFFFFFFF` ; cost depends on format module |
| CALM instruction count | none | time | `calminstruction` with `jump` to a prior label in its own body |
| include cycles (pre-depth-limit) | indirect (stack-depth) | memory | 10 000 opens before the catch |

## Experimental results

Full table from [examples/hang-suite/run.sh](../../examples/hang-suite/run.sh)
at 5-second timeout:

```
test                                          outcome  time(s)  outsize  note
----                                          -------  -------  -------  ----
calm/calm-internal-jump.asm                   TIMEOUT  5.10     -        no core guard
calm/calm-self-call.asm                       ERROR-2  0.05     -        parse-time rejection
expression/circular-equ-text.asm              ERROR-2  0.07     -        cycle detector
expression/circular-equ.asm                   OK       0.05     1        converges to 0
include-cycle/a.asm                           ERROR-2  0.13     -        stack-depth limit
multi-pass-oscillation/label-oscillation.asm  ERROR-2  0.08     -        pass-count limit
positive-control/petabyte-virtual.asm         OK       1.7      0        1 PiB virtual, 0 file
positive-control/petabyte-virtual-blocks.asm  OK       1.6      0        1 PiB virtual, 0 file
runaway-alloc/exponential-macro.asm           OK       0.05     32       calibration; add levels
runaway-alloc/nested-repeat.asm               TIMEOUT  5.08     -        ~15 s to complete
runaway-alloc/rb-huge.asm                     OK       0.05     0        `rb` is bookkeeping
runaway-alloc/repeat-bignum.asm               TIMEOUT  5.09     -        bignum count, effectively forever
runaway-alloc/repeat-huge.asm                 TIMEOUT  5.09     -        ~140 s to complete
single-pass-hang/repeat-bignum-no-body.asm    TIMEOUT  5.07     -        time-only runaway
single-pass-hang/self-macro.asm               ERROR-2  0.05     -        parse-time rejection
single-pass-hang/while-1-side-effect.asm      TIMEOUT  5.07     -        both axes unbounded
single-pass-hang/while-1.asm                  TIMEOUT  5.08     -        time-only, memory bounded
```

### Observations

**Well-guarded (caught quickly, no new work needed):**

- Self-referring macros (rejected at parse/first-call).
- Text-`equ` cycles (dedicated detector).
- Mutual `include` (stack-depth at ~10 000 iterations).
- Oscillating labels (pass-count at 100).

**Real hangs (no guard):**

- `while 1` with any body (empty or not) — infinite time.
- `repeat BIGINT` with a non-breaking body — infinite time, and
  memory if the body emits.
- CALM internal `jump` — infinite time inside the interpreter.

**Fast-but-wrong-looking that are actually fine:**

- `rb 0xFFFFFFFF` — assembles instantly; file output is 0
  because raw-format doesn't commit reserved bytes.
- Positive controls (petabyte virtual) — tally 1 PiB of
  bookkeeping in 0-byte files.

## Guidance for fasmg users and embedders today

### Users

1. **Don't rely on fasmg terminating.** Treat every invocation as
   "run with a timeout" in scripts and pipelines. `timeout 30s
   fasmg src.asm out.bin` in bash, `Start-Process … -Timeout`
   in PowerShell.
2. **Lower the built-in limits** when you know your project
   doesn't need them. `-p 20` catches pass oscillations 5× faster
   than default; `-r 200` catches include cycles 50× faster.
3. **Review macro bodies for recursive expansion.** An
   "exponential macro" pattern (a macro invoking two copies of
   the level below) blows up geometrically and is easy to miss.
4. **Avoid `while` and `repeat` without a body-controlled exit.**
   Sources should always make forward progress visible — a
   counter-driven `break`, a condition the body mutates, etc.
5. **Large counts are fine, but**: if your source has a literal
   `repeat 10000000 …`, be sure the math is necessary. Often an
   equivalent layout is expressible with `rb N` or a format-
   level sizing that completes instantly.

### Tool integrators (DLL, CI, IDE)

1. **Wrap every call in a wall-clock timeout.** The [Modern API
   D](../../source/windows/whp64/dll-next/) design has `timeout_ms`
   and `cancel_flag` parameters for exactly this. On direct-CLI
   integrations, shell-level `timeout`.
2. **Run fasmg in a separate process** if you care about clean
   recovery. An in-process DLL call with no kill-switch means the
   hang becomes your hang. The WHP-hosted build gives you
   `WHvCancelRunVirtualProcessor` for in-process clean-cancel;
   the direct DLL has no such primitive.
3. **Cap the file output at write time**, not at assembly time.
   Check the returned `MEMORY_REGION.size` / `fasmg_Buffer.length`
   against a project-appropriate ceiling before writing the
   artifact to disk.
4. **Consider per-job virtual memory limits** (job objects on
   Windows, `setrlimit` on Linux, cgroups on containerized CI).
   An OS-level OOM that kills just your job is a cleaner failure
   mode than an in-process `VirtualAlloc` that wraps through 4 GB.
5. **Never feed untrusted input into a direct DLL call.** The
   [DLL developer guide](../../source/windows/whp64/dll/DEVELOPER.md)
   notes the DLL is synchronous and non-cancellable. For
   untrusted input, the WHP-hosted build (or a sandboxed sub-
   process) is the right deployment surface.

## Proposed core-side changes

Two additions that close the observed gaps without changing
fasmg's semantics or rejecting any positive-control workload.

### 1. Wall-clock time limit

`maximum_time_seconds`, default 0 (no limit). When set, the core
checks elapsed time at "safe points" — the top of `assembly_pass`,
the top of each `repeat` / `while` iteration, and the start of
each CALM instruction dispatch. Exceeding the budget raises
"time limit exceeded" and exits.

**Cost**: one `get_timestamp` hypercall per safe point. The call
is cheap (~30 ns on Windows); amortized over many iterations,
it's noise. A thousand checks per second is ~3 μs of overhead.

**Benefit**: closes the biggest hole. Every infinite-loop class
becomes bounded-time, including the CALM-internal case that
nothing else catches.

**Caveat — safe-point density.** A tight CALM `jump` loop needs
the check *inside* the CALM interpreter's dispatch, not just at
directive boundaries. That's one added check in the hot path of
[source/calm.inc:1918-2100](../../source/calm.inc:1918), which
is well-scoped.

**Positive-control impact.** The `petabyte-virtual-blocks.asm`
test ran ~140 s at N = 24 on the user's machine. A default of
"off" is mandatory; any opt-in ceiling should be set by the
caller based on expected workload. A `timeout_ms` parameter at
the DLL or CLI boundary is the right surface, not a global
core default.

### 2. Committed output-file size limit

`maximum_output_bytes`, default 0 (no limit). Checked when the
output area's size is advanced during `db` / `dw` / `dd` /
`write`-style emissions. **Does not count:**

- Bytes inside `virtual ... end virtual` blocks (never in file).
- Bytes emitted before a `restartout` (discarded).
- Bignum tallies computed by the source for its own use.

The guard fires when the *current pending output area* exceeds
the cap. That metric is already tracked inside
[source/output.inc](../../source/output.inc) — the proposal is to
add one comparison per size-advance, not to reimplement the
sizing logic.

**Cost**: one compare-and-branch per size-advance. Free.

**Benefit**: a tool that wants to cap each user's output at,
say, 100 MB gets a clean core-level bound. The guard fires at
the offending `db` / `dw`, pinpointing the source line, rather
than at teardown after the file is written.

**Positive-control impact.** The petabyte-virtual examples emit
their literal data into `virtual` blocks or between `section`
boundaries followed by `restartout`. Under the proposed metric
they're 0-byte outputs; guard doesn't fire.

### Considered and dropped

- **Per-directive iteration cap.** My earlier draft included this;
  the positive-control examples argue against it. `repeat 2^20` is
  idiomatic; a cap on "iterations per directive" would either
  reject this legitimate work or be set so high it catches
  nothing. The time-axis proposal covers the real concern (how
  long is the assembly running?) without conflating it with
  iteration count.
- **Memory-usage ceiling for the core's heap.** The host-side
  allocator already knows its ceiling (`VirtualAlloc` fails on
  its own; cgroups memory limit kills the process; etc.). A
  core-side parallel ceiling just forces users to tune two
  numbers. Delegate to the system layer.
- **CALM instruction counter.** A subset of the wall-clock
  proposal. If (1) lands with a CALM-dispatch safe point, a
  separate CALM-only counter is redundant.
- **Include cycle detector.** The stack-depth guard already
  catches this. A dedicated detector would trade 10 000 opens
  for one normalized-path compare per include. Marginal against
  (1) which catches it in wall-clock terms regardless.

## Example suite

[examples/hang-suite/](../../examples/hang-suite/) is a runnable
test bench:

```bash
examples/hang-suite/run.sh                 # 5-second timeout
examples/hang-suite/run.sh 30              # 30-second timeout
examples/hang-suite/run.sh 5 /path/fasmg   # custom binary
```

The suite's [README](../../examples/hang-suite/README.md) documents
each test's class, mechanism, and expected outcome. Critically
it includes a `positive-control/` subdir whose members MUST
pass — idiomatic bignum-scale workloads that would be wrongly
caught by a naïve guard on "iteration count" or "bytes emitted
through `db` / `rb`."

Building this suite forced me to distinguish "what fasmg does
today" from "what I assumed it does." Four surprises:

1. `self-macro.asm` — I expected stack-depth; fasmg catches at
   parse / first-call as "illegal instruction." Cleaner guard.
2. `calm-self-call.asm` — rejected at parse; the real hang
   vector is body-internal CALM jumps, not recursive invocations.
3. Numeric `=` vs text `equ` cycles go through different paths;
   the former converges to 0, the latter trips a dedicated
   detector.
4. **The bignum reach.** `repeat (1 shl 128)` parses and runs
   exactly like any smaller count; my initial framing that
   iteration counts had a 32-bit ceiling was an unchecked
   assumption. The positive-control examples put this in
   perspective: bignum isn't a runaway risk, it's the design
   that makes petabyte-scale layout reasoning expressible.

These surprises are why the suite is valuable: it documents
actual-vs-expected behavior per category and keeps the
proposals honest. Extending it is straightforward — one `.asm`
per hypothesized failure, one line per expected outcome in the
README, re-run `run.sh` to verify.

## Companion to

- [whp64.md](whp64.md) — the WHP-hosted build was motivated
  partly by this problem: you can `WHvCancelRunVirtualProcessor`
  an untrusted assembly even when it's stuck in a CALM loop.
- [core_text_delegation.md](core_text_delegation.md) — the
  "time limit exceeded" / "output size limit exceeded" messages
  proposed here would naturally be `MSG_*` entries under that
  delegation plan.
- [uefi_fasmg.md](uefi_fasmg.md) — UEFI has no multi-process
  sandboxing, so proposal (1) is more valuable there than on
  Windows or Linux. Firmware can't spawn a watchdog.
