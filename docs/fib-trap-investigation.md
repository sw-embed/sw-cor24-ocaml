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
