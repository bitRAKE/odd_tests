# fasmg hang / runaway-allocation test suite

A set of fasmg sources that exercise the core's behavior under
inputs that hang, consume unbounded resources, or — in the
positive-control subdir — look astronomical but are legitimate
idiomatic usage that must not be caught by any guard.

Running this suite at the boundary of any caller that hands fasmg
untrusted (or just big) input is a cheap sanity check on how
robust that caller is to build-time denial-of-service, and a
reality check on the costs of any proposed core-side guard.

## Quick start

```bash
./run.sh                       # 5-second timeout, uses ../../fasmg.exe
./run.sh 10                    # 10-second timeout
./run.sh 5 /path/to/fasmg.exe  # custom binary
```

Output is a table of `(test, outcome, wall-time, output-size,
last-stderr-line)`. Outcomes:

| outcome    | meaning |
|---|---|
| `OK`       | fasmg exited 0 |
| `ERROR-N`  | fasmg exited N (assembly-level error or resource limit) |
| `TIMEOUT`  | killed at the wall-clock budget |
| `KILLED`   | killed by the OS (usually OOM) |

## Two axes of runaway

fasmg uses bignum arithmetic everywhere — iteration counts,
section sizes, address tallies. That means **time** and **memory**
are independent axes of unboundedness, and every runaway falls
into exactly one quadrant:

| | memory bounded | memory unbounded |
|---|---|---|
| **time bounded** | (normal assembly) | `rb` in committed section, `db` in moderately large loop |
| **time unbounded** | `while 1`, `repeat BIGINT` with no emission, CALM `jump` | `while 1 { db 0 }`, `repeat BIGINT { db 0 }` |

The bignum mechanics also enable legitimate workloads that look
astronomical but cost nothing: a `repeat 2^20` emitting into
`section` or `virtual` blocks can "reserve" exabytes of *virtual*
address space with zero real memory growth. See the
`positive-control/` subdir for examples.

## What each test demonstrates

### `positive-control/` — MUST pass

- **`petabyte-virtual.asm`** — `repeat 2^20` with `rb 1 GB` into
  fresh `section` per iteration. Tallies 1 PiB of virtual bytes as
  bignum; final output 0 bytes after `restartout`. ~1.7 s.
  Demonstrates that bignum-scale virtual-address reasoning is
  idiomatic, not pathological.
- **`petabyte-virtual-blocks.asm`** — same idea with `virtual ...
  end virtual` blocks and a second `repeat` summing `sizeof`. Same
  conclusion; different primitive.

### `single-pass-hang/` — time-unbounded, memory-bounded

- **`while-1.asm`** — empty `while 1` body. Tight interpreter
  loop. No output, no allocation, runs forever.
- **`repeat-bignum-no-body.asm`** — `repeat (1 shl 128)` with
  no emission (body evaluates `if 0 ... end if`). Time is
  effectively unbounded; memory flat. The bignum count is the
  point: fasmg will dutifully work through every iteration.
- **`self-macro.asm`** — macro that calls itself. Caught at parse
  / first-call as "illegal instruction" rather than by stack
  depth.

### `single-pass-hang/while-1-side-effect.asm` and `runaway-alloc/*` — both axes unbounded

- **`while-1-side-effect.asm`** — `while 1` with `db 0`. Output
  grows without bound alongside time.
- **`repeat-huge.asm`** — `repeat 1000000000 { db 0 }`. 1 billion
  iterations, ~140 s of wall clock, ~1 GB of output. Finite,
  but indistinguishable from a hang to any observer with a
  reasonable patience budget.
- **`repeat-bignum.asm`** — `repeat (1 shl 128) { db 0 }`. The
  count is bignum; effectively never terminates. Upgrade of
  `repeat-huge` for "clearly not going to finish."
- **`nested-repeat.asm`** — `10000 * 10000 = 100 M` iterations
  emitting a byte each. ~15 s to complete; calibration point for
  "slow but finite."
- **`exponential-macro.asm`** — macros calling sub-macros, each
  twice. 5 levels = 32 bytes; add levels to grow `2^N`. Shows
  how runaway hides in ordinary-looking source (no literal giant
  number anywhere).
- **`rb-huge.asm`** — `rb 0xFFFFFFFF`. Reserves 4 G of virtual
  space in one line; output file is 0 bytes, assembly is instant.
  Whether this is a "runaway" depends entirely on whether a
  format module later file-backs the region.

### `multi-pass-oscillation/`

- **`label-oscillation.asm`** — a value that depends on its own
  prior existence; pass `N` disagrees with pass `N-1` forever.
  The pass-budget (default 100) catches it. Lower `-p` catches
  it faster.

### `include-cycle/`

- **`a.asm` ↔ `b.asm`** — mutual `include`. No cycle detection,
  but `maximum_depth_of_stack` (default 10 000) catches it at
  the ~10 000-th nested include. Lower `-r` catches it faster.

### `expression/`

- **`circular-equ.asm`** — two numeric `=` constants pointing at
  each other. fasmg converges to `0` via standard two-pass
  forward-reference mechanics; not a hang.
- **`circular-equ-text.asm`** — same idea with text `equ`. fasmg
  trips a dedicated cycle detector and errors cleanly.

### `calm/`

- **`calm-self-call.asm`** — CALM instruction invoking itself by
  name. fasmg rejects at parse time; not a hang vector today.
- **`calm-internal-jump.asm`** — `jump label` inside a single
  CALM body. The interpreter in `source/calm.inc` has no
  instruction-count ceiling; a tight CPU-level infinite loop
  inside one calminstruction call. **Hardest hang to recover
  from** — no directive stack growth to trigger the depth guard.

## Observed outcomes at 5-second timeout

Stable across machines; `TIMEOUT` rows depend on CPU speed but
the outcome column itself is stable.

| test | outcome | note |
|---|---|---|
| `calm/calm-internal-jump.asm` | TIMEOUT | real hang (no core guard) |
| `calm/calm-self-call.asm` | ERROR-2 | rejected at parse |
| `expression/circular-equ-text.asm` | ERROR-2 | cycle detector |
| `expression/circular-equ.asm` | OK | resolves to 0 |
| `include-cycle/a.asm` | ERROR-2 | stack limit |
| `multi-pass-oscillation/label-oscillation.asm` | ERROR-2 | pass limit |
| `positive-control/petabyte-virtual.asm` | OK | 1 PiB virtual, 0 output |
| `positive-control/petabyte-virtual-blocks.asm` | OK | 1 PiB virtual, 0 output |
| `runaway-alloc/exponential-macro.asm` | OK | 32 bytes, calibration |
| `runaway-alloc/nested-repeat.asm` | TIMEOUT | ~15 s to complete |
| `runaway-alloc/rb-huge.asm` | OK | 0 bytes (bookkeeping only) |
| `runaway-alloc/repeat-bignum.asm` | TIMEOUT | effectively never |
| `runaway-alloc/repeat-huge.asm` | TIMEOUT | ~140 s to complete |
| `single-pass-hang/repeat-bignum-no-body.asm` | TIMEOUT | time-only runaway |
| `single-pass-hang/self-macro.asm` | ERROR-2 | rejected early |
| `single-pass-hang/while-1-side-effect.asm` | TIMEOUT | forever |
| `single-pass-hang/while-1.asm` | TIMEOUT | forever |

## Lessons

1. **fasmg has three built-in guards**: pass count (default 100),
   error count (1000), stack depth (10 000). Each catches a
   specific structural class. None catches unbounded *time* or
   *memory* inside a single pass.
2. **Counts are bignum.** `repeat N` where `N = 2^128` parses
   and iterates normally; there is no fixed counter ceiling in
   the core. "When does it terminate?" reduces to "when does the
   body run through every iteration or hit `break`?"
3. **Time and memory are independent axes.** `while 1` with
   no body is time-unbounded / memory-bounded. `rb 2^32` is
   time-bounded / memory-unbounded-at-write. Guards must target
   the specific axis.
4. **The real hangs are**: `while` with a truthy condition,
   `repeat` with a bignum count and a body, CALM with internal
   jumps. These three have no core-side ceiling; caller-side
   wall-clock enforcement is the only current defense.
5. **Timeouts are not optional** for tools invoking fasmg on
   untrusted input. A purely CPU-bound `repeat 10^9` takes
   minutes — indistinguishable from a true hang to any observer
   or build system.
6. **Positive controls set the ceiling for guards.** The
   petabyte-virtual examples complete in ~1.7 s at N = 20 and
   ~140 s at N = 24. Any wall-clock default must account for
   legitimate workloads in this range.

## Using this suite in CI

The script's exit is the exit of the last invocation, which isn't
useful. For CI use, compare the `outcome` column against the
expected values. A trivial check:

```bash
actual=$(./run.sh | tail -n +3 | awk '{print $1, $2}')
diff <(cat expected_outcomes.txt) <(echo "$actual") && echo ok
```

Leave `TIMEOUT` rows flexible — they're the wall-clock bound,
not a hard count — but verify the `OK` and `ERROR-2` rows match.
