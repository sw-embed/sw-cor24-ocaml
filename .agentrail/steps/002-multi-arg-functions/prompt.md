Add multi-argument function support.

Currently fun x -> body only supports one argument. OCaml allows:
  fun x y -> x + y   (sugar for fun x -> fun y -> x + y)

Changes needed:
- Parser: in parse_expr's TK_FUN branch, after reading the first parameter,
  check if the next token is another IDENT (not ARROW). If so, collect
  multiple parameters and desugar into nested funs.
  fun x y z -> body  becomes  fun x -> fun y -> fun z -> body

Test: let add = fun x y -> x + y in print_int (add 20 22)  outputs 42
Update test_eval.pas and create reg-rs baselines.