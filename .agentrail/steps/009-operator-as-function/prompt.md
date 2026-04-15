Allow operators as first-class functions via parens: (+), (*), (::), etc.

Use case: 'List.fold_left (+) 0 [1;2;3;4]'.

Parser: in parse_atom's TK_LPAREN branch, if the content inside parens
is a single operator token (TK_PLUS, TK_MINUS, TK_STAR, TK_SLASH, etc.),
desugar to 'fun a -> fun b -> a OP b' and return that.

Handle all arithmetic/compare/logic binops. cons (::) and list concat.

Tests:
  > (+) 3 4                 7
  > (*) 6 7                 42
  > let op = (+) in op 10 20   30
  > (=) 3 3                 true