Add semicolon sequencing to the OCaml interpreter.

OCaml uses ; to sequence expressions: e1; e2 evaluates e1 (discarding result), then e2.

Changes needed:
- Lexer: TK_SEMI is already tokenized
- Parser: add a new precedence level below let/if/fun that handles e1; e2
  Grammar: seq_expr ::= expr (';' expr)*
  The top-level parse_expr should call parse_seq which chains with semicolons
- Evaluator: new AST node EK_SEQ with left=e1, right=e2, or reuse EK_LET with a dummy name
  Simpler: desugar e1; e2 into let _ = e1 in e2 during parsing

Test: let x = 1 in print_int x; print_int 2  outputs 1 then 2
Update test_eval.pas (the combined program) and create reg-rs baselines.