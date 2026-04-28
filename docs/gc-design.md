# OCaml runtime GC design

Companion to `docs/heap-survey.md`. Documents the design choices for the
mark/sweep collector being added in saga `ocaml-heap-reclaim` (steps
005–006), targeting issues #28 and #29.

## Goal

The interpreter's heap fills up across multiple top-level eval
transactions (issue #28), even though most allocated objects are
unreachable garbage by the time the next transaction begins. Add an
internal mark/sweep collector that reclaims unreachable
Expr/Pat/Val/EnvEntry objects, so heap growth is bounded by what is
actually live at the start of each transaction.

## Collection trigger

**Top of REPL only.** The collector runs once at the top of the REPL
loop, between top-level transactions. It does NOT run mid-eval.

Why: at the top of REPL, all parser/eval call frames have unwound and
no heap object is referenced solely from a Pascal stack local. The root
set collapses to the single global env pointer. This eliminates the
need for a push/pop root stack across parser/eval entry points (which
the original step prompt called for) and keeps the collector simple
and proc-budget-friendly.

A future iteration could add mid-eval collection (with the root-stack
instrumentation) if a workload arises that allocates more in a single
transaction than a freshly-collected heap can hold. None of the known
acceptance fixtures (including the #28 repro) need this.

## Root set

The mark phase begins from exactly one root:

- `top_env: PEnv` — the persistent global environment.

Everything reachable from `top_env` is live: env entries, the values
they bind, closures and their captured bodies + capture envs,
list/pair/option/ctor structures, refs and their cells, records and
their field chains, AST bodies that closures point into.

Anything *not* reachable from `top_env` at the top of REPL is
guaranteed-dead garbage and may be freed.

The other globals that the marker could conceivably touch (`ast`,
`result`) point into objects that are either reachable through
`top_env` (because the just-completed transaction bound something) or
unreachable garbage (because nothing was bound). Either way they don't
need to be additional roots — `ast` is overwritten on the next
iteration by `parse_seq`, and `result` is dead after print.

## Pointer-field map (the marker's reference)

Per `docs/heap-survey.md` and the type declarations in
`src/ocaml.pas:42-77`:

```
mark(p: PExpr):
  if p = nil or p^.mark_bit <> 0: return
  p^.mark_bit := 1
  mark(p^.left); mark(p^.right); mark(p^.extra)
  mark_pat(p^.pat)

mark_pat(p: PPat):
  if p = nil or p^.mark_bit <> 0: return
  p^.mark_bit := 1
  mark_pat(p^.sub1); mark_pat(p^.sub2)

mark_env(p: PEnv):
  if p = nil or p^.mark_bit <> 0: return
  p^.mark_bit := 1
  mark_val(p^.val); mark_env(p^.next)

mark_val(p: PVal):
  if p = nil or p^.mark_bit <> 0: return
  p^.mark_bit := 1
  case p^.vk of
    VK_CLOSURE:
      mark(p^.body); mark_env(p^.cenv)
      mark_val(p^.head); mark_val(p^.tail)   { mk_partial: f, acc }
    VK_CONS, VK_PAIR:    mark_val(p^.head); mark_val(p^.tail)
    VK_SOME:             mark_val(p^.head)
    VK_CTOR:             mark_val(p^.head)
    VK_FIELD:            mark_val(p^.head); mark_val(p^.tail)
    VK_RECORD:           mark_val(p^.head)
    VK_REF:              mark_val(p^.head)
    VK_INT/BOOL/NIL/NONE/STRING/UNIT: pass
```

Marking the bit before recursing breaks cycles (closures + refs).

## Sweep

After mark, walk each per-type alloc list (`expr_alloc_head`,
`pat_alloc_head`, `val_alloc_head`, `env_alloc_head`) and for each
node:

- If `mark_bit = 0`: splice out of the list and `dispose()` it.
- If `mark_bit = 1`: clear it back to `0` for the next collection,
  keep it on the list.

Step 003 confirmed Pascal `dispose(p)` correctly returns blocks to
`sys_free`'s coalescing free list, so the sweep does not need any
special accounting.

## Mark-bit lifecycle

The `mark_bit: integer` field on each record is uninitialized at
`new()` time. The collector's first action is to walk all four lists
and clear the bit on every live allocation; only then does the mark
phase run. After sweep, all surviving objects are guaranteed to have
`mark_bit = 0` (per the rule above), so the *next* collection's clear
pass is a confirmation walk rather than a correctness requirement.

## Proc/symbol budget

The vendored Pascal compiler (p24p) caps procedure declarations at 128
(`MAX_PROCS = 128` in compiler/src/parser.h of sw-cor24-pascal — see
upstream issue #21 to lift that cap). `src/ocaml.pas` is at exactly 127
procedures today.

Implications for step 006:

- Prefer **a single `gc_collect` procedure** that does clear + mark +
  sweep inline, with a `case` dispatch on `vk`/`pk`/`kind` rather than
  separate per-type helpers.
- Avoid recursive procedures where iteration would do (the marker has
  to traverse cyclic graphs anyway, but the AST/env shapes are mostly
  trees, so explicit work-stack iteration is fine).
- If we cannot fit `gc_collect` in one proc within budget, the fallback
  is to inline the whole collector at its single call site (top of
  REPL loop), but that is a last resort.

## Acceptance criteria recap

- `top_env`-only marking is sufficient to drop the parser/eval garbage
  from prior transactions.
- After collection, heap growth across N transactions is O(live state),
  not O(allocations). The #28 stress fixture should run to completion
  with no `TRAP 5`.
- All existing tests pass — collection is invisible to programs that
  don't approach the heap limit.
