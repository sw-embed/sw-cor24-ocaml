Implement strings (step 003 was marked complete prematurely by a background task).

See original prompt in archive or step 003 for details. Core tasks:

Lexer:
- Recognize double-quoted string literals. Handle escapes: \n \t \" \\.
- New TK_STRING token.
- Intern string content into a global string_pool[0..4095] of char.

AST / Value:
- VK_STRING=10 value kind
- Val uses noff/nlen as the offset/length in string_pool
- mk_val_string(off, len): PVal
- EK_STRING=13 AST node
- mk_string_expr(off, len): PExpr
- eval: EK_STRING -> mk_val_string

Built-ins:
- print_endline : string -> unit (write chars then CR+LF)
- String.length : string -> int
- ^ operator: concat two strings, returning new string in pool

Parser:
- TK_STRING in parse_atom -> EK_STRING node
- Add ^ as a binop (TK_CARET) at arith-level precedence (like +/-)
- Actually let's add at its own level between compare and arith.
  Simplest: make ^ a TK_CARET token and add to parse_arith alongside + -.

Pretty-printer:
- VK_STRING -> '"content"' (just raw chars between quotes; no re-escaping)

Tests:
  > "Hello"                            "Hello"
  > "OCaml" ^ " rocks"               "OCaml rocks"
  > print_endline "Hello, World!"      Hello, World!  (then unit)
  > String.length "abcde"              5