Split the lexer out of ocaml.pas into a separate compilation unit.

Create src/oc_lex_unit.pas containing:
- All lexer constants (TK_xxx)
- Lexer globals (tok, tok_int, tok_id, tok_id_len)
- Source buffer (src, src_len, pos)
- All lexer functions (is_digit, is_alpha, skip_*, classify_ident, lex_init, lex_next)

Use the p24p unit compilation mechanism (uses units, external declarations).
Update src/ocaml.pas to import the lexer unit instead of inlining it.
Verify the multi-unit build pipeline works.
All 26 regression tests must still pass.