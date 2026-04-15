Add 'when' guards to pattern match arms: 'match x with n when n < 0 -> -n | n -> n'.

Lexer: add TK_WHEN keyword.

Parser: in parse_match arm parsing, after the pattern but before '->':
  if tok = TK_WHEN, lex_next and parse a guard expression.
  Store guard in the arm (use a new pat2 or guard field on EK_MATCH_ARM;
  since EK_MATCH_ARM's extra is unused, use extra = guard expression).

Evaluator: in the EK_MATCH arm loop, after successful try_match:
  if arm has a guard, eval it in extended env; if guard is false/int 0,
  treat as match failure and continue to next arm.

Tests:
  > match -5 with n when n < 0 -> 0 - n | n -> n           5
  > match 3 with n when n < 0 -> 0 - n | n -> n            3
  > let abs x = match x with n when n < 0 -> 0 - n | n -> n in abs (-7)   7
  > match 10 with n when n > 20 -> "big" | _ -> "small"  (once strings exist)