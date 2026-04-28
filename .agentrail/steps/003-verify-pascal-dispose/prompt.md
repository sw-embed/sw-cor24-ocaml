# Step: verify-pascal-dispose

Verify that Pascal `dispose(p)` actually frees memory in the host build
chain, before the GC work in later steps relies on it. The reporter of
issue #29 noted that dispose support was previously fixed in the
sw-cor24-pcode repo, but the OCaml host has never exercised it.

## Why this gates the rest

Step 005 (`mark-sweep`) calls `dispose` on every unmarked OCaml
allocation. If `dispose` does not actually return the block to the
free list — or if it traps, or is a no-op, or has stale-allocator
issues — the sweep step does nothing useful and the #28 trap returns.
We need to know the answer before writing the marker.

## What to do

1. Write a tiny standalone Pascal program (e.g.,
   `tests/test_dispose.pas` or similar minimal scaffolding) that:
   - Allocates a small record via `new()`,
   - Reads back its value to confirm allocation worked,
   - Calls `dispose()` on it,
   - Allocates again and confirms the address is reused (or that
     subsequent alloc still succeeds at expected heap-pointer offset),
   - Loops the alloc/dispose pair many times and confirms the heap
     pointer does not grow without bound (i.e., free list is reclaimed).
2. Build it through the same toolchain `scripts/build.sh` uses (p24p →
   pl24r → pa24r) and run it on cor24-run with a heap_limit small
   enough that an alloc-only loop would trap.
3. Confirm the loop completes without TRAP 5.
4. If `dispose` works as expected: record the test in the repo so it
   stays as a regression guard, commit, and proceed.
5. If `dispose` is broken or a no-op: stop the saga, report findings to
   the user, and propose either a pcode-repo fix path (which would
   require explicit auth per CLAUDE.md repo-boundary rule) or a host-
   side workaround.

## Out of scope

- Do not modify sibling repos (sw-cor24-pcode, sw-cor24-pascal) — only
  exercise their existing behavior.
- Do not add any GC infrastructure to `src/ocaml.pas` yet; that is
  step 003 onward.

## Done when

- A dispose-stress test exists in `tests/` (or appropriate location)
  and passes through the standard build pipeline.
- The test exhibits bounded heap growth across many alloc/dispose
  iterations under a small heap_limit, providing positive evidence
  that the free list works.
- Findings recorded in step summary.
- Committed and pushed.
