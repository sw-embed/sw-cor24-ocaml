Parse the match expression.

Syntax:
  match_expr ::= 'match' expr 'with' match_arms
  match_arms ::= ('|'? pattern '->' expr) ('|' pattern '->' expr)*

Grammar note: the first '|' is optional.

In parse_expr, add TK_MATCH branch:
- lex_next
- scrutinee := parse_expr
- if tok = TK_WITH then lex_next else parse_error
- parse arms: optionally TK_PIPE, then pattern, then TK_ARROW, then expr (body)
- build EK_MATCH AST with scrutinee as left, first arm as right
- each arm has next pointer via extra (or use pattern in noff-like slot)

Be careful with the trailing expr -- when does an arm end? When we see
TK_PIPE followed by pattern, OR we hit a natural boundary. For now,
require explicit | between arms. The body is parsed with parse_expr
which doesn't consume |.

Test:
  > match 3 with 0 -> 100 | _ -> 42
  42
  > match 0 with 0 -> 100 | _ -> 42  
  100
  > match [] with [] -> 0 | _ -> 1
  0
  > match [1; 2; 3] with [] -> 0 | h :: t -> h
  1