Add qualified identifier parsing (List.length etc).

Lexer: add TK_DOT for '.'.
Parser: in parse_atom's TK_IDENT case, after reading the ident,
if the next token is TK_DOT and the following token is TK_IDENT,
append '.' + next-ident to tok_id. Continue for further dots.

Example: input 'List.Foo.bar' -> single qualified identifier
  'List.Foo.bar' stored in the name pool, EK_VAR node references it.

No evaluator changes -- env_lookup and names_equal already work
with arbitrary-length names. A qualified name that isn't a built-in
will simply fail env_lookup with EVAL ERROR.

Test: parser accepts 'List.length [1;2;3]' without syntax error.
(It will EVAL ERROR because List.length isn't defined yet.)