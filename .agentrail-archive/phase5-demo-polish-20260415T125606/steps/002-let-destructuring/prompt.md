Extend 'let' to accept a pattern on the left-hand side.

Currently:
  let <IDENT> = expr in body
  let rec <IDENT> = expr in body

New:
  let <PATTERN> = expr in body   (equivalent to: let __tmp__ = expr in match __tmp__ with PATTERN -> body)

For let rec, keep the existing identifier-only form (recursive
destructuring doesn't make sense without type info we don't have).

Parser change in parse_expr's TK_LET branch:
- After lex_next and optional TK_REC:
  - If tok is TK_IDENT (not rec case), peek: is the NEXT token TK_EQ?
    If yes, use the simple ident binding (existing behavior).
    If not, fall through to pattern parsing.
  - Actually simpler: if rec, require ident; else parse a pattern.
    If pattern is PK_VAR, use the existing fast path.
    Otherwise desugar to let + match.

Tests:
  > let (a, b) = (1, 2) in a + b                                       -> 3
  > let (x, y) = (10, 20) in let (p, q) = (3, 4) in x + y + p + q       -> 37
  > let h :: t = [1; 2; 3] in h                                       -> 1  (partial; match failure if nil)
  > let [a; b; c] = [10; 20; 30] in a + b + c                          -> 60
  > let (x, [a; b]) = (1, [2; 3]) in x + a + b                         -> 6