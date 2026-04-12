Implement the OCaml tokenizer in Pascal.

Create src/oc_lex.pas that tokenizes:
- Integer literals
- Identifiers and keywords (let, in, if, then, else, fun, true, false, not, mod)
- Operators: +, -, *, /, =, <>, <, >, <=, >=, &&, ||, ->
- Delimiters: (, )
- Whitespace skipping
- Comments: (* ... *)

Reference docs/design.md for the token set.
Test with simple inputs via reg-rs regression tests.