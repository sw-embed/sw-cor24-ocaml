Implement the tree-walk evaluator and environment model in Pascal.

Create src/oc_value.pas with value types: VInt, VBool, VClosure, VUnit.
Create src/oc_env.pas with environment as linked list of (name, value) bindings.
Create src/oc_eval.pas with recursive AST evaluator:
- Integer arithmetic and comparisons
- Boolean logic (&&, ||, not)
- let bindings (extend environment)
- if/then/else (conditional evaluation)
- Function definition (create closure capturing environment)
- Function application (evaluate function and argument, extend closure env)
- Built-in print_int primitive

Create src/oc_prim.pas with print_int: outputs integer to UART/stdout.

Test evaluation of:
- Arithmetic: 2 + 3 * 4 = 14
- Let: let x = 5 in x + 1 = 6
- Conditional: if 1 = 1 then 42 else 0 = 42
- Function: let f = fun x -> x + 1 in f 41 = 42
- print_int: let x = 42 in print_int x outputs 42

Reference docs/design.md for value and AST representations.