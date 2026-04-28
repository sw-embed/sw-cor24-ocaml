# Step: define-roots

Define and instrument the GC root set so a future mark phase has a
well-defined starting graph. Still no collection.

## Roots, at minimum

- The global environment.
- The current eval environment (may equal global at REPL top level).
- The in-flight parsed expression(s) during a parse transaction.
- Active closures (anything referenced by a value currently bound in env).
- Parser/evaluator temporaries on the call path: AST nodes under
  construction, pattern matchers under construction, partial result
  values.

The first three are reachable via existing globals. The last two require
explicit push/pop instrumentation in parser/eval entry points so that
temporaries reachable only through Pascal stack locals become visible to
the mark phase.

## What to do

1. Add a small root-stack API: `gc_push_root(p)`, `gc_pop_root()`, plus
   `gc_with_root(p, body)` if Pascal control flow allows it cleanly.
2. Identify the parser/evaluator entry points where temporaries can be
   live across an allocation that could otherwise reclaim them.
   Instrument those with push/pop. Be conservative — over-rooting is
   safe; under-rooting causes use-after-free.
3. Add a `gc_iter_roots` helper that the future mark phase will call.
4. No collection trigger yet. Tests must still pass; behavior is unchanged.

## Out of scope

- No mark or sweep yet.
- Do not call `gc_iter_roots` from anywhere except a self-test.

## Done when

- Root API exists.
- Parser/eval entry points are instrumented per the survey from step 2.
- Self-test prints expected roots in a known scenario (REPL with one
  binding, mid-parse).
- `just test` passes.
- Committed and pushed.
