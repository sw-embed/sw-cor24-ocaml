Implement AST types and recursive descent parser in Pascal.

Create AST node types using pointer records (PExpr = ^Expr) for:
- IntLit, BoolLit, Var
- BinOp (arithmetic, comparison, logic)
- UnaryOp (not)
- If (cond, then, else)
- Let (name, value, body)
- Fun (param, body)
- App (func, arg)

Create recursive descent parser implementing the Phase 0 grammar from docs/design.md:
- Operator precedence: logic < comparison < arith < term < unary < app < atom
- Parenthesized expressions
- Function application by juxtaposition

Test parsing by building a combined lex+parse test that parses expressions and prints AST structure.
Use reg-rs tests. Vendored Pascal compiler now supports pointers, new, dispose, exit.