Add the 'function' keyword as syntactic sugar for 'fun __arg__ -> match __arg__ with ...'.

Lexer:
- Add TK_FUNCTION keyword (8-char ident 'function'). Update classify_ident.

Parser:
- In parse_expr, add TK_FUNCTION branch:
  - lex_next (consume 'function')
  - Generate a fresh hidden variable name (use '_fn_arg_' or similar;
    intern once at startup as 'function_arg_noff/nlen')
  - Optional leading TK_PIPE
  - Parse arms exactly as parse_match does
  - Build: mk_fun_node(match_expr) where match_expr is
    EK_MATCH whose scrutinee is a reference to the hidden arg name
  - The fun_node uses the hidden arg name as its parameter

Tests:
  > let f = function 0 -> 100 | 1 -> 101 | _ -> 999 in f 0   -> 100
  > let f = function [] -> 0 | h :: t -> h in f [42; 99]      -> 42
  > let abs = function n -> if n < 0 then 0 - n else n in abs (-5)  -> 5
  > (function 0 -> "zero" | _ -> "many") 3                      (* deferred -- no strings yet *)

Commit with green tests.