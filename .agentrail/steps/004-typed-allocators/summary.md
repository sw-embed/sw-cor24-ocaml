# Step 004 — typed-allocators: findings

## Outcome

Every one of the 44 `new(...)` sites in `src/ocaml.pas` now threads its
new object onto a per-type tracking list at the moment of allocation.
The four lists (`expr_alloc_head`, `pat_alloc_head`, `val_alloc_head`,
`env_alloc_head`) are the worklist that the future mark/sweep
collector (steps 006) will walk. All 100 reg-rs tests pass; the #28
repro still traps as expected (we haven't added the sweep yet).

## What changed

1. Added `next_alloc` field to each of the four heap-allocated record
   types (`Expr`, `Pat`, `Val`, `EnvEntry`).
2. Added four global head pointers initialized to `nil` at REPL
   startup.
3. After every `new(<var>)` call, three statements run inline:
   ```
   <var>^.next_alloc := <type>_alloc_head;
   <type>_alloc_head := <var>;
   ```
   This intrusive linked list is built in O(1) per allocation, in
   reverse order (newest at head). Sweep order does not matter for
   mark/sweep correctness.

## Departures from the original step prompt

The prompt called for typed allocator *functions* (`alloc_expr`,
`alloc_pat`, etc.) and per-type alloc *counters*. Both were dropped
during implementation because the vendored Pascal toolchain has hard
table caps that the OCaml host source is already brushing up against:

- **Procedure cap = 127.** The original `src/ocaml.pas` declares
  exactly 127 procedures/functions (a power-of-2 boundary). Adding
  even one more triggers `error: too many procedures (got VAR)` from
  p24p. So no `alloc_*` helper functions could be added.
- **Symbol cap.** Adding the four counters (8 globals — head + count
  per type) tripped a separate `too many symbols (got IDENT)` error.
  Heads alone (4 new globals) fit; counters did not.

The functional outcome is identical to what the prompt was asking for:
the per-type tracking lists exist and are populated. Only the
ergonomic packaging (helpers, counters) is missing. The inline
tracking adds 2 statements per `new()` site — verbose but mechanical.

## Constraint to carry into steps 005/006

Future GC code (root-stack API, mark traversal, sweep+dispose) must
fit within the same proc/symbol budget. Specifically:

- **Adding new procedures requires removing existing ones** to stay
  ≤ 127. Each step 005/006 procedure must be either inlined or paired
  with a deletion of an unused proc.
- **Be parsimonious with new globals.** The symbol cap is shared
  across vars, types, and procs.
- A natural pattern for the marker/sweeper: write each as a single
  procedure with a `case` on `vk`/`pk`/`kind` rather than per-kind
  helpers. That keeps the proc count flat.

## Correctness notes for the marker

- `next_alloc` is only ever written, never read, by host code today.
  The marker added in step 006 will be the first reader. So the
  current step is a structural change with no behavioural effect.
- The lists are append-at-head, so iteration traverses
  newest-to-oldest. The collector does not depend on traversal order.
- `next_alloc` is set BEFORE any other field on the record, but
  AFTER `new()`. Since `new()` returns an uninitialized block,
  reading `next_alloc` is safe (we always write it first).

## Verification

- `./scripts/build.sh` — succeeds.
- `just test` — 100/100 pass (unchanged from step 003 baseline).
- `bash $TUPLET_REPO/scripts/repro-ocaml-issue28.sh` — still traps
  with TRAP 5 (expected; no sweep yet).

## Next step (005 — define-roots)

With every allocation now on a tracking list, step 005 can implement
the root-stack API and instrument parser/eval entry points. The
budget constraint stands: define-roots' helpers should be parsimonious
(ideally one or two procs total).
