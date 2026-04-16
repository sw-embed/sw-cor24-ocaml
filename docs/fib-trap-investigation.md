# Fib trap investigation (phase7 step 001 — characterize)

Investigation of why `let rec fib n = if n < 2 then n else fib (n-1) + fib (n-2) in fib N`
fails on the COR24 OCaml interpreter for small N.

All runs use `cor24-run` with `-n 1000000000` (1B-instruction budget) so the budget
is not the limiting factor. Step 001 is **characterization only** — no source changes.

## Recursive `fib N` sweep

| N  | Outcome                  | Instructions | UART tail (after echo) |
|----|--------------------------|--------------|------------------------|
| 1  | success                  | 1,835,962    | `1`                    |
| 2  | success                  | 2,272,363    | `1`                    |
| 3  | success                  | 2,708,764    | `2`                    |
| 4  | success                  | 3,581,566    | `3`                    |
| 5  | success                  | 4,890,769    | `5`                    |
| 6  | success                  | 7,072,774    | `8`                    |
| 7  | success                  | 10,564,624   | `13`                   |
| 8  | success                  | 16,237,846   | `21`                   |
| 9  | **`EVAL ERROR`** (clean) | 3,733,411    | `EVAL ERROR`           |
| 10 | **`TRAP 4`** (INVALID_OPCODE) | 3,415,640 | `TRAP 4`            |
| 11 | **`TRAP 4`**             | 3,415,640    | `TRAP 4`               |
| 12 | **`TRAP 4`**             | 3,415,640    | `TRAP 4`               |

Notes:
- N=1..8 grow roughly as expected for naive fib (≈ φ-scaled instruction count).
- N=9 produces the interpreter's **clean** `EVAL ERROR` text — the evaluator
  detected an exhausted resource and reported it.
- N=10, 11, 12 produce the **identical** instruction count (3,415,640) and trap
  with INVALID_OPCODE. Identical counts across three different inputs prove the
  trap fires deterministically at the same point in the *interpreter's* execution,
  not at a point that depends on what `fib N` would compute. Once the resource
  is exhausted at recursion depth ~K, any N ≥ 10 hits the corruption at the same
  instruction.

## Non-recursive let-chain control

Programs of the form `let v0 = 1 in let v1 = v0 + 1 in ... in v(d-1)` for depth
`d`. These exercise lex/parse/eval over a long source with many bindings but
**no recursion**.

| depth | Outcome    | Instructions |
|-------|------------|--------------|
| 10    | success    | 4,864,712    |
| 25    | success    | 660,910,000  |
| 50    | success    | 657,040,000  |
| 100   | success    | 579,370,000  |
| 150   | success    | 388,580,000  |

(Instruction counts here are dominated by per-character UART read+lex cost, not
by binding evaluation; the point is that **150 nested bindings complete cleanly**.)

## What this rules in / rules out

The trap is **recursion-specific**, not a generic heap or binding-environment
problem. A 150-deep let-chain — which builds a 150-entry environment of
integers — runs to completion. So the value heap and the binding lookup path
both work fine at sizes well past what `fib 10` needs (peak recursion depth 10,
~177 calls).

The fact that `fib 9` produces a clean `EVAL ERROR` but `fib 10` produces
`TRAP 4 (INVALID_OPCODE)` strongly suggests **a fixed-size per-call resource
(activation record / value stack / closure heap) is being exhausted, and the
exhaustion check is incomplete**: one allocation path notices and reports
cleanly (the `fib 9` path), but another allocation path (or a different
exhaustion mode at one extra frame's worth of depth) does **not** notice, and
the interpreter then dispatches through corrupted state — landing the PC on
non-opcode bytes. Identical instruction counts for N=10/11/12 confirm the
failure is a single deterministic state-corruption event, not anything
data-dependent on N itself.

This points step 002 (diagnose) at the recursive-call path: where activation
records / closure environments are allocated for `fib`'s recursive call, and
which of those allocations lacks an "out of room" check that the `fib 9` path
does have.

## Diagnosis (phase7 step 002)

**Root cause: the PVM call stack overflows silently.** The missing guard is
in the VM, not in `src/ocaml.pas`. The step 001 hypothesis ("activation-record
allocator on the recursive path lacks an exhaustion check") is correct in
shape but one level down: the exhausted resource is the *PVM* call stack,
not an OCaml-level heap cell.

### The allocations that *do* check

Every OCaml-level allocation goes through Pascal's `new()`, which the p24p
runtime (`vendor/sw-pascal/v0.1.0/bin/runtime.spc:454`, `_p24p_new`) services
via PVM `sys 4` (ALLOC). The ALLOC handler in `vendor/sw-pcode/v0.1.0/bin/pvm.s:2796`
compares the new heap pointer against `heap_limit` and traps cleanly with
code 5 (HEAP_OVERFLOW) on overflow. Value-stack pushes (`op_push`,
`op_push_s` at pvm.s:608 / pvm.s:640) likewise compare `esp < heap_seg` and
trap with code 2 (STACK_OVERFLOW). A 150-deep let-chain works for this
reason — the env chain, value heap, and eval-stack growth are all
bounds-checked.

### The allocation that does *not* check — and corrupts state

The PVM has a third stack, the **call stack** (`pvm.s:3258`, 1536 bytes =
exactly 512 words). Its pointer `csp` is bumped by three opcodes:

| Opcode | Advance | File:line | Bounds check? |
|---|---|---|---|
| `op_call` (0x33) | `csp += 12` (frame header) | pvm.s:1183 | **NO** |
| `op_calln` (0x35) | `csp += 12` | pvm.s:1327 | **NO** |
| `op_enter` (0x40) | `csp += nlocals * 3` | pvm.s:1401 | **NO** |

Grepping the whole VM confirms `call_stack` is referenced only at init
(pvm.s:45) to set the base — there is no `call_stack_limit` symbol and no
`csp < X` comparison anywhere. By contrast the eval stack has an explicit
overflow check and the heap has a limit.

### How this becomes TRAP 4

Memory layout (pvm.s:3258 onward):

```
call_stack   (1536 B, csp grows up)   ← NO overflow check
eval_stack   (1536 B, esp grows up)   ← esp < heap_seg check only
heap_seg     (grows up to heap_limit)
```

The compiled interpreter's core function is `_user_eval_expr`, declared
with **15 locals** (build/ocaml.spc:9040: `.proc _user_eval_expr 15`).
Each invocation therefore grows `csp` by `12 (op_call frame header) +
15*3 (op_enter locals) = 57 bytes`. The call stack holds at most
`1536 / 57 ≈ 26` nested `eval_expr` frames before `csp` crosses into
`eval_stack` memory.

The OCaml `fib` body `if n < 2 then n else fib (n-1) + fib (n-2)`
nests roughly 4–5 `eval_expr` frames per recursive OCaml call
(EK_APP → EK_IF → EK_BINOP → EK_APP → body EK_IF…). At OCaml recursion
depth 10, peak Pascal `eval_expr` depth is ≈ 40–45 frames — well past
the 26-frame capacity.

Once `csp` advances past `call_stack`'s end, subsequent `op_call` writes
frame headers (return PC, dynamic link, static link, saved esp) **into
eval_stack memory**. Either path (a) or (b) then fires:

- **(a) Return-PC corruption.** A later value push overwrites the return-PC
  word of a frame header that now lives inside eval_stack. When the owning
  call returns, `op_ret` (pvm.s:1220) reads `pc = frame[0]` = garbage, sets
  `vm_state.pc` to a non-code address, dispatch reads a non-opcode byte →
  **TRAP 4 (INVALID_OPCODE)**.
- **(b) Saved-esp corruption.** `op_ret` restores `esp = saved_esp - nargs*3`;
  if `saved_esp` is garbage, subsequent loads read random memory as AST/Val
  pointers — usually crashes somewhere the interpreter's `nil` / `vk` guards
  will catch (explains why `fib 9`, whose overflow is smaller, produces a
  clean `EVAL ERROR`: the corruption is contained to values that a guard
  still notices, rather than the active frame header's return PC).

Identical instruction counts (3,415,640) for N=10/11/12 are consistent with
(a): the trap fires on the exact `op_ret` whose frame header was first
overwritten, which is input-independent because the overflow depth and
eval_stack write pattern are both determined by the interpreter's own
structure, not by `N`.

### Specific missing guard

In `vendor/sw-pcode/v0.1.0/bin/pvm.s`, three opcodes advance `csp`
without bounds-checking:

- `op_call` at pvm.s:1209–1211 — `add r2, 12; sw r2, 6(fp)`
- `op_calln` at pvm.s:1392–1394 — `add r2, 12; sw r2, 6(fp)`
- `op_enter` at pvm.s:1425–1427 — `add r2, r0; sw r2, 6(fp)` (r0 = nlocals*3)

Each advances `csp` and commits it to `vm_state.csp` with no comparison
against the end of `call_stack` (= start of `eval_stack`).

### Fix sketch (1–2 lines — do not implement in this step)

Mirror the existing `op_push` overflow check. Before committing the
advanced `csp`, compare it against `eval_stack` and trap with code 2
(STACK_OVERFLOW) on overrun:

```
    ; (after computing new csp in r2)
    la r0, eval_stack
    clu r2, r0
    brt csp_ok
    lc r0, 2
    la r2, vm_trap
    jmp (r2)
csp_ok:
    sw r2, 6(fp)      ; commit new csp
```

Apply in all three sites (`op_call`, `op_calln`, `op_enter`). This is a
VM change, so it does **not** grow `src/ocaml.pas` (hard 65 KB limit
unaffected). Converts silent corruption into clean `TRAP 2`, matching
the existing eval-stack / heap overflow behavior.

**Alternative** (if touching the vendored VM is undesirable): add a
recursion-depth counter to `eval_expr` in `src/ocaml.pas` that sets
`eval_error := true` once depth exceeds a safe bound (~20). Compact
(~3 lines) but papers over the VM bug; the VM fix is correct.
