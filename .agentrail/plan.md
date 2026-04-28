# Saga: ocaml-heap-reclaim

Address GitHub issues #28 (two-pass memory-backed Tuplet parse trap) and #29
(add runtime reclaim/GC for OCaml heap objects) at root cause rather than by
continuing to bump pool sizes and heap limits.

## Goal

The OCaml interpreter (`src/ocaml.pas` and friends) currently allocates heap
objects (AST nodes, patterns, values, env entries, records, refs, closures,
strings, lists) via raw `new(...)` with no reclamation path. Every prior
"capacity issue" (#14, #20, #27, #28) was patched by raising a pool ceiling.
This saga implements real reclaim so the interpreter has bounded heap growth
across a series of top-level eval transactions.

Concrete blocker driving the work: issue #28. After the first pass of a
two-pass memory-backed parse registers a syntax declaration and produces an
AST, the second lex/parse pass traps with TRAP 5 because retained
parser/registry/value state has filled the heap. The repro in
sw-vibe-coding/tuplet `scripts/repro-ocaml-issue28.sh` is the acceptance
fixture.

## Acceptance criteria

- #28 repro runs without TRAP 5 against this branch's `ocaml.p24m`.
- All existing host tests pass (`just test` clean).
- A new stress test that runs many parse/eval transactions in a single
  session shows bounded heap growth (no monotonic exhaustion).
- No user-visible `free`/`dispose` API; reclaim is internal.
- `src/ocaml.pas` allocations route through typed helpers, not raw `new`.

## Step plan

1. **repro-issue-28** (research)
   Reproduce issue #28 from sw-vibe-coding/tuplet and confirm the diagnosis
   that the trap is heap exhaustion (not a lexer/state bug). Capture heap
   usage at the moment of trap. Record the answer in the step summary.
   Output: a confirmed repro path on this host, instrumented if needed, and
   a yes/no on "is this OOM in the OCaml heap".

2. **survey-allocation-sites** (research)
   Catalog every `new(...)` site in `src/ocaml.pas` (and any other host
   source that allocates OCaml runtime objects) by kind: expr, pat, val,
   env, record, ref, closure, string, list-cons. Identify retention
   relationships (which kinds reference which). No code changes.

3. **typed-allocators** (refactor)
   Introduce `alloc_expr`, `alloc_pat`, `alloc_val`, `alloc_env`,
   `alloc_string`, `alloc_list`, etc. Replace raw `new(...)` calls with
   these helpers. Each helper threads the new object onto a per-kind
   tracking list (intrusive next link or side metadata, whichever fits the
   record layouts). No collection yet; allocation behavior must be
   identical to today. All existing tests must pass.

4. **define-roots** (refactor)
   Implement an explicit GC root set: the global environment, the current
   eval environment, the in-flight parsed expression, active closures, and
   any temporaries the parser/evaluator pushes during a transaction.
   Exposed as helpers `gc_push_root` / `gc_pop_root` for parser/eval
   scopes. Still no collection.

5. **mark-sweep** (feature)
   Implement mark/sweep over the kinds tracked in step 3, traversing from
   the roots defined in step 4. Trigger a collection (a) at the end of each
   top-level eval transaction and (b) before reporting heap overflow.
   Add internal counters for objects allocated, marked, and swept.

6. **stress-test-and-issue-28** (validation)
   Add a host-level stress test that loops parse/eval transactions and
   asserts bounded growth. Run the #28 repro from sw-vibe-coding/tuplet
   and confirm it completes. Run `just test` and report any regressions.
   On pass, close issues #28 and #29 with links to the saga steps.

7. **promotion-and-cleanup** (validation)
   Final validation: full test suite, focused fixtures, brief perf
   smoke (parse/eval throughput should be unchanged or better), README
   note if any externally observable behavior changed. Confirm
   `agentrail audit` shows no orphan commits.
