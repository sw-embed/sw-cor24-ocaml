Add pattern arguments to function-form let: 'let swap (x, y) = (y, x)'.

Currently function-form let only supports identifier args: 'let f x y = ...'. Extend to accept any pattern: tuple '(x,y)', unit '()', cons 'h::t', wildcard '_', etc.

Parser: in parse_let, when parsing each parameter position after the function name, call parse_pattern_atom instead of only expecting TK_IDENT. Each parameter becomes a synthetic fun/match pair: 'let f P1 P2 = body' desugars to 'let f = fun #a1 -> match #a1 with P1 -> fun #a2 -> match #a2 with P2 -> body'. Alternatively, bind each param pattern directly on the lambda if the evaluator supports that.

Test: tests/eval_function_pattern_args.ml:
  let swap (x, y) = (y, x) in swap (1, 2)                        => (2, 1)
  let fst3 (a, b, c) = a in fst3 (10, 20, 30)                    => 10
  let head (h :: _) = h in head [1; 2; 3]                        => 1
  let f () = 42 in f ()                                           => 42
  let add (x, y) = x + y in add (3, 4)                           => 7

Register with reg-rs. Keep src/ocaml.pas well under 131K. Note: build.sh uses the default 10s time limit which is now marginal — may need to pass -t 60 (or bump MAX_INSTRS elsewhere) to build reliably.