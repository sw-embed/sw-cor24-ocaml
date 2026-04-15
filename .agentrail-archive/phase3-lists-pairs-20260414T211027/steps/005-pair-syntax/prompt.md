Add pair syntax to the parser.

Add TK_COMMA ','.

Update parse_atom for parenthesized expressions:
  ( expr )       -> expr (existing)
  ( expr , expr ) -> mk_pair expr expr (new)

Test:
  (1, 2)          -> (1, 2)
  fst (1, 2)      -> 1
  snd (1, 2)      -> 2
  let p = (10, 20) in fst p + snd p   -> 30