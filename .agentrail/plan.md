Clean up pre-existing reg-rs baseline failures (unrelated to TCO but
surfaced while verifying the TCO saga), and produce a design plan for
the next major correctness work: heap management / garbage collection.

Pre-existing failures (from commit de562aa and earlier, NOT my TCO
change):
  - lex_all, lex_arith, lex_fun, lex_let — stderr "Assembled N bytes"
    diff only; interpreter assembly grew when new builtins were added
    and again with the TCO trampoline. Mechanical rebase.
  - demo_adventure, demo_echo_loop, demo_guess — .ml sources were
    updated in de562aa (exit builtin, welcome messages, help command).
    Baselines still echo the old sources. Mechanical rebase.
  - eval_string_conversion — BEHAVIOR change: `int_of_string ""`
    used to produce EVAL ERROR, now produces 0. Need to understand
    whether this is an intentional change, a masked bug, or a
    regression before rebasing. int_of_string on empty string in
    real OCaml raises Failure _, so neither result is strictly
    correct, but we should make a deliberate choice.

Plus a planning step for the next saga:
  - Heap management / GC. Current state: every tail-call iteration
    allocates PVal/PEnv nodes that are never reclaimed. After ~100
    iterations of demo_adventure, heap_limit (0x00F000 = ~40KB over
    heap_seg) is exhausted and TRAP 5 (HEAP_OVERFLOW) fires.
    TCO solved the stack problem; the heap is now the limiting factor.
    The plan step should sketch approach options (stop-the-world
    mark-sweep, generational, reference counting, arena reset per
    top-level expression, etc.) with tradeoffs, but not implement.

Steps:
  1. investigate-int-of-string-empty: decide correct behavior for
     int_of_string "" and either (a) rebase the baseline with current
     0-returning behavior if we accept it, or (b) fix the behavior to
     raise EVAL ERROR and keep the baseline.
  2. rebase-stale-baselines: rebase the 7 mechanical failures
     (lex_* + demo_* after #1 is resolved).
  3. plan-gc: produce docs/gc-plan.md sketching heap management
     options and recommending a starting approach.