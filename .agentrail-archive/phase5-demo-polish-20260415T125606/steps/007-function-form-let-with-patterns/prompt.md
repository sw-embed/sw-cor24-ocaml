Extend function-form let to accept pattern arguments: 'let swap (x, y) = (y, x)'.

Combines with let-destructuring from step 002.

Parser: in function-form-let, each parameter position may be a pattern
instead of an ident. If it's not just TK_IDENT, parse as pattern and
desugar to 'fun _tmp -> match _tmp with PATTERN -> body'.

Tests:
  > let swap (x, y) = (y, x) in swap (1, 2)                (2, 1)
  > let fst2 (a, b) = a in fst2 (10, 20)                   10
  > let first (h :: _) = h in first [42; 99]               42
  > let sum_pair (a, b) = a + b in sum_pair (3, 4)         7