Add function-form let: 'let f x = body' as sugar for 'let f = fun x -> body', and 'let f x y z = body' for nested funs.

This is the highest-leverage demo unlock — enables ~8 of the canonical demos:
  let f x = x + 1
  let square x = x * x
  let add x y = x + y
  let rec fact n = if n = 0 then 1 else n * fact (n - 1)
  let rec fib n = if n < 2 then n else fib (n-1) + fib (n-2)
  let compose f g x = f (g x)
  let safe_div x y = if y = 0 then None else Some (x / y)

Parser change in parse_expr's TK_LET branch:
- After reading the ident name, if tok is TK_IDENT (parameter) rather
  than TK_EQ (plain binding), collect 1+ parameter names until TK_EQ.
- Desugar: 'let f x y = body in rest' becomes
  'let f = fun x -> fun y -> body in rest'.
  Works with let rec too.

Tests:
  > let f x = x + 1 in f 5                          6
  > let square x = x * x in square 7                49
  > let add x y = x + y in add 20 22                42
  > let rec fact n = if n = 0 then 1 else n * fact (n - 1) in fact 5   120
  > let rec fib n = if n < 2 then n else fib (n-1) + fib (n-2) in fib 7   13