# Step 003 — verify-pascal-dispose: findings

## Verdict: **YES, Pascal `dispose(p)` actually frees memory.**

End-to-end smoke through the standard build pipeline confirmed it. The
prior fix in the pcode repo holds: `dispose` is real, not a no-op or
stub, and the free list correctly reuses freed blocks so an
alloc+dispose loop has bounded heap growth.

## What was tested

`tests/test_dispose.pas` — a tiny Pascal program that loops 10000
`new(p)` / `dispose(p)` pairs over a small `Node` record and prints
`DISPOSE_OK` at the end. Default `heap_limit` in pvm.s is `0x00F000`
(~60 KiB ≈ 5000 minimum-size blocks), so 10000 iterations are 2×
heap capacity. Without working dispose, this would TRAP 5 around
iteration 5000.

I also ran a 20000-iteration version (4× capacity) during exploration;
it likewise completed cleanly in ~77M instructions. The committed test
uses 10000 to stay under `run-pascal.sh`'s default 50M instruction
budget so it fits cleanly into the regression suite.

## How dispose is implemented (vendored runtime + pvm)

Traced the chain:

- Pascal `dispose(p)` → `_p24p_dispose` (runtime.spc:503).
- `_p24p_dispose` calls `sys 5` (FREE) unconditionally on the pointer
  (runtime.spc:505), then increments `_h_fc` and clears the slot in the
  16-entry tracking table `_h_pt`.
- `sys 5` lowers to `sys_free` in pvm.s:3133 (with full free-list
  insertion and neighbour coalescing).
- The 16-entry tracking table in the Pascal runtime is for leak
  reporting only — `_p24p_new` skips tracking once the table is full
  (runtime.spc:472), but the underlying `sys 4` (ALLOC) and `sys 5`
  (FREE) still happen for every call. So **dispose works correctly
  regardless of how many objects are outstanding** — the 16-entry
  table is not a free-list cap.

This matters for the GC step (006 in the saga): the future mark/sweep
collector will potentially have hundreds of unmarked allocations to
sweep at once. Each call to `dispose` is independent at the VM level,
so the sweep can call `dispose` on every unmarked pointer without
worrying about the runtime tracking table.

## Repro / regression coverage

- `tests/test_dispose.pas` — committed.
- `work/reg-rs/pascal_dispose_stress.{rgt,out}` — wired into the
  regression suite. `just test` is now 100/100, up from 99/99.

## Implications for the saga

- Step 005 (`mark-sweep`)'s sweep phase can use straightforward
  Pascal `dispose(p)` on each unmarked allocation. No new runtime
  primitives or pcode changes needed.
- The "real fix" framing of issue #29 holds: the missing piece is
  entirely host-side liveness tracking. Underneath, both `sys_alloc`
  and `sys_free` are correct and ready.

## Next step (004 — typed-allocators) is unblocked

Step 004 can proceed: introduce `alloc_expr`/`alloc_pat`/`alloc_val`/
`alloc_env` allocator helpers in `src/ocaml.pas`, route the 44
`new(...)` sites from `docs/heap-survey.md` through them, and set
up per-type tracking lists. No collection logic yet; `dispose` will
be invoked from the sweep phase added later.
