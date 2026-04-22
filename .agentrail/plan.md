Add tail-call optimization to eval_expr in src/ocaml.pas so that recursive
OCaml programs (let rec loop / REPL-style interactive demos) run in constant
Pascal-stack space.

Problem: each OCaml tail call recurses in Pascal; after ~8 iterations the
p-code VM's call stack overflows with TRAP 2. Reproducible with
`OCAML_STDIN=$'look\nlook\n...\n' ./scripts/run-ocaml.sh tests/demo_adventure.ml`.

Approach: wrap eval_expr's body in a `while true do ... exit` loop and
rewrite each tail-position recursive call to reassign (e, env) and continue
the loop instead of recursing. Tail positions to convert:
  - EK_LET body (r)
  - EK_IF taken/untaken branch
  - EK_APP closure body (user closures only, not builtins)
  - EK_MATCH arm body

Non-tail subexpression evaluation (EK_BINOP operands, EK_APP function/arg
evaluation, EK_MATCH scrutinee, guard expression) continues to recurse --
bounded by expression depth, not iteration count.

Steps:
  1. tco-eval-expr: implement trampoline in eval_expr; confirm existing
     tests/regressions still pass; add a regression that loops read_line
     100+ times without trap.