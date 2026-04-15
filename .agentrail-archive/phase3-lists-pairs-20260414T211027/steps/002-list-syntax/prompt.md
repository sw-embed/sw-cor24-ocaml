Add list syntax to the parser.

Add tokens to the lexer:
  TK_LBRACKET   '['
  TK_RBRACKET   ']'
  TK_COLONCOLON '::'

Add a global 'nil' identifier that evaluates to VK_NIL (recognized
in EK_VAR like print_int).

Add list literal parsing in parse_atom:
  []        -> nil
  [e]       -> cons e nil
  [e1; e2]  -> cons e1 (cons e2 nil)
  [e1; e2; e3] -> cons e1 (cons e2 (cons e3 nil))

Add :: as a right-associative binary operator (precedence between
arithmetic and comparison). Parse e1 :: e2 as cons.

Test:
  []                    -> []  (or some indicator)
  [1; 2; 3]            -> displays as list
  1 :: 2 :: []         -> equivalent
  hd [1; 2; 3]         -> 1
  tl [1; 2; 3]         -> [2; 3]
  is_empty []          -> true