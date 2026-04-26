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

Open GitHub issue blocker plan (2026-04-25):

These are the currently open repo issues. Add them as pending saga
steps after the in-progress baseline cleanup so other agents can pick
work from a single ordered backlog.

Priority order:
  - #1 demo_adventure TRAP 2 is first because it is a concrete runtime
    bug affecting the web embedding and the interactive demo.
  - #3 top-level let bindings is second because it removes the largest
    host-language pain for Tuplet-style multi-expression programs.
  - #2 user-defined variants is third because it unlocks natural token
    and AST representations after top-level definitions exist.
  - #4 string escapes and 3+ tuples is fourth because both have working
    Tuplet fallbacks, but they reduce parser/test boilerplate.

Additional steps:
  3. fix-demo-adventure-trap2: reproduce GitHub issue #1, isolate the
     stale state or value/env lifetime problem after Cave -> Hall ->
     Cave, fix the interpreter/PVM bug, and add a regression that drives
     `look`, `take`, `inventory`, `n`, `s`, `take`, `quit`.
  4. top-level-let-bindings: implement persistent top-level `let` /
     `let rec` declarations across a file, including function shorthand,
     while preserving existing expression and REPL behavior.
  5. user-defined-variants: support `type t = A | B` and constructors
     with payloads, with parsing, runtime representation, matching, and
     regression coverage for token/AST-style examples.
  6. string-escapes-and-tuples: recognize common string escapes and
     support tuple literals and patterns of arity >= 3.

Deferred from the original plan:
  - plan-gc: produce docs/gc-plan.md sketching heap management options
    and recommending a starting approach. Do this after the open issue
    blockers unless heap exhaustion becomes the immediate blocker again.
