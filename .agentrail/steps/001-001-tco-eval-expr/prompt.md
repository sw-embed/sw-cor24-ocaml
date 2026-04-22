Implement tail-call optimization in eval_expr (src/ocaml.pas:1400).

Goal: recursive OCaml programs like tests/demo_adventure.ml's `let rec
loop` run in constant Pascal-stack space regardless of iteration count.

Implementation: wrap the body of eval_expr in a `while true do ... end`
trampoline. At every tail-position recursive call, instead of calling
eval_expr(...) and returning its result, reassign the loop's (e, env)
locals and fall through to the next iteration. Tail positions:

  - EK_IF: taken and untaken branches
  - EK_LET: body expression (non-rec and rec both)
  - EK_APP: when applying a user closure (fv^.body <> nil and not a
    builtin), the closure body is a tail call. Builtins (print_int,
    read_line, exit, etc.) stay as-is.
  - EK_MATCH: the matched arm's body (and only the body -- guard
    expressions are NOT tail positions).

Non-tail recursion stays: binop operand evaluation, match scrutinee,
match guards, app function and argument evaluation. These are bounded
by expression depth, not iteration count.

Validation:
  1. `just test` -- existing regressions still green.
  2. Manual: `OCAML_STDIN=$(yes look | head -100 | tr -d '\n' | sed 's/look/look\n/g') ./scripts/run-ocaml.sh tests/demo_adventure.ml`
     completes without TRAP 2 (prints the cave description ~100 times).
  3. Add a regression test (e.g. tests/demo_loop_depth.ml + entry in
     work/reg-rs/) that exercises at least 100 `let rec` iterations and
     is covered by `just test`.

Files in scope:
  - src/ocaml.pas (eval_expr)
  - tests/ (new regression)
  - work/reg-rs/ (regression registration)
  - justfile (if a new demo target helps)

Do not touch sibling repos (sw-cor24-pcode, sw-cor24-pascal, sw-em24).
Do not expand scope beyond TCO + its regression.