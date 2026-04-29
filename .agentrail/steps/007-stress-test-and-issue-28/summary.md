# Step 007 — stress-test-and-issue-28: findings

## Outcome

Both target issues closed; the saga's acceptance is met.

- **GitHub #28** (TRAP 5 on two-pass memory-backed Tuplet parse) — fixed
  by step 006's `gc_collect`. Verified by running the full repro from
  the sibling Tuplet repo end-to-end; the second pass now produces the
  expected `IDENT do/body/while/cond/end EOF` token stream in ~8.4B
  instructions.
- **GitHub #29** (add runtime reclaim/GC for OCaml heap objects) —
  closed with a comment summarizing what landed across saga steps
  004/005/006/007 and the open follow-up
  (sw-cor24-pascal#22 for marker speedup).

## What landed in this step

- `tests/stress_gc.ml` — 100 successive allocation-heavy top-level
  transactions in one session. Each transaction allocates a 10-element
  list and a `List.length` call's worth of intermediate cons cells.
  Without GC, the heap fills around iteration 50; with GC,
  every transaction starts from a near-empty heap.
- `work/reg-rs/stress_gc.{rgt,out}` — wired into the regression suite
  as test `stress_gc`. The expected output is the prompt sequence plus
  a final `42`. `just test` is now 101/101.

## Acceptance criteria check

| Criterion (saga plan)                                | State |
|------------------------------------------------------|-------|
| #28 repro runs without TRAP 5                        | ✅    |
| Existing eval/parser/lexer tests still pass          | ✅ (101/101) |
| Stress test shows bounded heap growth                | ✅    |
| No user-level `free`/`dispose` API                   | ✅    |
| `src/ocaml.pas` allocations route through tracking   | ✅ (next_alloc per kind) |

## Performance note

Per-transaction `gc_collect` runs O(N²) due to the iterative
fixed-point marker (single procedure, no helpers — see step 006
summary for why). The #28 repro takes ~4× the pre-GC instruction
count. Acceptable for now; recursive helpers are blocked on
sw-cor24-pascal#22 (`PROC_NAME_SIZE` coupling). Once that ships,
the marker can drop to O(N).

## Next step (008 — promotion-and-cleanup)

Final validation pass: full test suite (already at 101/101), README
update if anything externally observable changed, `agentrail audit`
to confirm no orphan commits, and mark the saga done.
