Add list syntax to the parser AND hd/tl/is_empty built-ins.

Lexer:
- Add TK_LBRACKET '[' and TK_RBRACKET ']'
- Add TK_COLONCOLON '::' (two colons). Need to distinguish from single ':' which is not yet used. Recognize '::' as one token.

Parser:
- In parse_atom, recognize TK_LBRACKET:
  - []              -> nil (use the existing intern'd 'nil' name via mk_var_node-like approach, or directly build cons chain ending in nil)
  - [e]             -> cons(e, nil)
  - [e1; e2]        -> cons(e1, cons(e2, nil))
  - [e1; e2; e3]    -> cons(e1, cons(e2, cons(e3, nil)))
  Parse elements separated by ';' until ']'.
- Add :: as a binary operator between compare and arith level (right-assoc).
  Create a new parse_cons level: parse_cons ::= parse_arith (:: parse_cons)?
  Use a new OP code OP_CONS that mk_binop creates; eval treats it as mk_val_cons.

AST / Eval:
- EK_BINOP with OP_CONS: eval both sides, mk_val_cons(lhs, rhs)
- For list literal []: can parse as a call to nil or as a special AST node. Simplest: add a new EK_NIL kind, or just use EK_VAR with 'nil'.

Built-ins (add to intern_ functions, EK_VAR, and EK_APP dispatch):
- hd : cons -> a     (head of cons cell, error on nil)
- tl : cons -> list  (tail of cons cell, error on nil)
- is_empty : list -> bool

Tests:
  > []
  []
  > [1]
  cons
  > 1 :: nil
  cons
  > is_empty nil
  true
  > is_empty [1]
  false
  > hd [42]
  42
  > tl [1; 2; 3]
  cons

Pretty-printing of cons cells as [1; 2; 3] is the next step.