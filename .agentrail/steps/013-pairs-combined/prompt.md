Add pair (2-tuple) values and syntax in one step.

Values:
- Add VK_PAIR=7 constant.
- mk_val_pair(a, b): reuse head field for first, tail for second.
- print_value for VK_PAIR: '(a, b)' with recursive print.

Syntax:
- Add TK_COMMA ','.
- Update parse_atom's TK_LPAREN branch: after parsing first expr,
  if tok = TK_COMMA, parse second expr, expect TK_RPAREN, build
  EK_BINOP with OP_PAIR. (Could do n-tuples later with right-assoc
  commas; for now just 2-tuples.)

Eval:
- EK_BINOP with OP_PAIR: eval both, mk_val_pair.

Built-ins:
- fst : pair -> 'a (head)
- snd : pair -> 'b (tail)

Tests:
  > (1, 2)          (1, 2)
  > fst (1, 2)      1
  > snd (1, 2)      2
  > let p = (10, 20) in fst p + snd p   30
  > (1, [2; 3])     (1, [2; 3])