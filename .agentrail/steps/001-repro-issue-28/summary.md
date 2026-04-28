# Step 001 — repro-issue-28: findings

## Repro confirmed

Ran `bash /Users/mike/github/sw-vibe-coding/tuplet/scripts/repro-ocaml-issue28.sh`
against host commit `a12418c` and Tuplet commit `91c0424`. Output ends
exactly as the issue describes:

```
DEBUG first
PROGRAM
... (syntax-expand AST dump) ...
END
DEBUG tokens
IDENT  do
IDENT  body
IDENT  wTRAP 5
```

The first parse pass succeeds and prints the expected AST. The trap fires
mid-token in the second lex pass.

The one-pass control (`tuplet_parse_memory_assignment` via reg-rs) still
passes, so the trap is specific to the two-pass scenario.

## Trap identified

`TRAP 5` originates in the p-code VM (pvm.s, vendored at
`vendor/sw-pcode/v0.1.0/bin/pvm.s`), specifically the `alloc_bump`
overflow path:

```
pvm.s:3082-3103 (sys_alloc → alloc_bump)
  ; Heap overflow check: new_hp < heap_limit
  la r0, heap_limit
  lw r0, 0(r0)
  clu r1, r0
  brt alloc_bump_ok
  lc r0, 5             <-- trap code 5
  la r2, vm_trap
  jmp (r2)
```

This is reached only when (a) the free list is empty (`alloc_walk` →
`alloc_bump`) and (b) the bump-allocated upper bound `new_hp` exceeds
`heap_limit`. **TRAP 5 = heap-overflow on bump.**

## Heap layout for memory-input runs

`scripts/run-ocaml.sh` patches the runtime as follows:

- `pvm.bin` at `0x000000` (code base)
- `ocaml.p24m` at `0x040000` (relocated OCaml interpreter image)
- `heap_limit` patched to `0x03F000`

So the OCaml host's heap can grow up to `0x03F000` (≈ 258 KiB minus the
pvm code and globals). Across loading and evaluating ast.ml + registry.ml
+ parser.ml + lexer.ml + lex_bridge.ml plus the debug_main fragment from
the repro, the host accumulates AST/env/value/registry state with no
reclamation. The second-pass lex then allocates a few list-cons cells
per token and tips over the limit.

## Diagnosis: YES, this is OCaml-host heap exhaustion

Three observations support the issue reporter's diagnosis:

1. The trap is the documented bump-overflow path in the p-code VM.
2. The control case (single-pass smaller program) succeeds, ruling out a
   lexer state-machine or parser two-pass-restart bug as the primary cause.
3. The p-code runtime already implements `sys_free` (sys id 5, pvm.s:3133)
   with free-list coalescing — so dispose support exists at the VM level.
   The missing piece is at the OCaml host: `src/ocaml.pas` makes ~50
   `new(...)` calls with no corresponding `dispose` / liveness tracking.

The reporter's framing of #29 as "the real fix" stands. Continuing the
saga as planned.

## No instrumentation added

The trap mechanism and heap layout were enough to confirm the diagnosis
from existing artifacts (pvm.s source, run-ocaml.sh patches). No code or
debug prints were added to this repo, so there is nothing to revert.

## What this unblocks

Step 002 (`survey-allocation-sites`) can begin from `src/ocaml.pas` and
the other host modules in `src/` to catalog all `new(...)` sites by
runtime kind.
