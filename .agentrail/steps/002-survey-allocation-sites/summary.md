# Step 002 — survey-allocation-sites: findings

## Scope

`build/ocaml.p24m` is built from a single source file, `src/ocaml.pas`
(see `scripts/build.sh`). The interpreter image that traps in issue #28
contains exactly the 44 `new(...)` sites in that file. Other Pascal
sources under `src/` (oc_ast, oc_eval, oc_value, oc_lex, oc_parse) are
small modules used only by `tests/test_*.pas` and are not in the #28
trap path. They are noted in the survey but not on the GC worklist.

## Counts

44 production `new(...)` sites in `src/ocaml.pas`, distributed across
four Pascal record types:

- 16 `Expr` allocations (14 named `mk_*` helpers + 2 inline in `parse_atom`)
- 11 `Pat` allocations (10 named `mk_pat_*` helpers + 1 inline)
- 16 `Val` allocations (12 named `mk_val_*` helpers + `mk_partial` + 3 inline in `eval_expr`)
- 1  `EnvEntry` allocation (`env_extend`, line 1137)

## Survey artifact

Committed `docs/heap-survey.md` (commit `bd4f7b8`) with:

- Definitions of the four Pascal record types and their pointer fields.
- A per-site table for each Pascal type: line, helper/context, logical
  runtime kind, and which pointer fields are live.
- A per-VK pointer-field map (the marker's reference) — `Val` is heavily
  overloaded by `vk`, so `head`/`tail`/`body`/`cenv` are interpreted
  per kind and the marker has to dispatch on `vk`.
- The cross-type edges that force whole-graph traversal before any
  sweep:
    - Expr → Expr, Pat
    - Pat → Pat
    - Val → Expr (closure body), Env (closure env), Val (head/tail)
    - Env → Val, Env
- The non-heap allocation surfaces (name_pool, string_pool, src buffer,
  ctor tables) — fixed-capacity static arrays, not `new()`-allocated,
  so out of GC scope.
- Confirmation that there are **no** manual mark/release patterns, **no**
  custom arenas, and **no** existing `dispose` calls in `src/ocaml.pas`.
  Allocation is strictly `new()`-then-leak.
- Confirmation that the p-code runtime already exposes `sys_free`
  (pvm.s:3133), so Pascal `dispose(ptr)` lowers cleanly. The collector
  does not need new runtime support.

## Key liveness implication for the marker

Closures pin both their body `Expr` graph and the captured `EnvEntry`
chain alive. An environment containing a closure transitively retains
the lambda body that created the closure. This rules out naive
"sweep all AST after each eval" — the AST is reachable through closures
that escape into the global environment.

## Worklist handed to step 003

1. Add `alloc_expr`/`alloc_pat`/`alloc_val`/`alloc_env` helpers, each
   threading the new object onto a per-type tracking list (parallel
   bounded-array table, since records lack a spare pointer for an
   intrusive `next_alloc`).
2. Replace all 44 `new(...)` sites with the matching helper. The 14
   named `mk_*` helpers are single-line edits; the 5 inline sites
   (`parse_atom` lines 552, 571, 889; `eval_expr` lines 1854, 1860,
   2160) need in-place edits.
3. Add per-type alloc counters readable from the dump path to give
   step 005 a baseline.

After step 003 the interpreter's behavior is identical: allocate-and-
leak as today, just routed through helpers. The #28 repro still traps.
