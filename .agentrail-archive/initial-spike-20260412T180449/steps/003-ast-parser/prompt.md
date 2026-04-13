Implement AST types and recursive descent parser in Pascal.

Create src/oc_ast.pas with AST node definitions for:
- IntLit, BoolLit, Var
- BinOp (arithmetic, comparison, logic)
- UnaryOp (not)
- If (cond, then, else)
- Let (name, value, body)
- Fun (param, body)
- App (func, arg)

Create src/oc_parse.pas with a recursive descent parser implementing the Phase 0 grammar from docs/design.md:
- Operator precedence: logic < comparison < arith < term < unary < app < atom
- Parenthesized expressions
- Function application by juxtaposition

Test parsing of expressions, let bindings, if/then/else, function definitions.
Use reg-rs tests (can test via AST pretty-print or parse-then-eval).