Implement the tree-walk evaluator, environment model, and print_int primitive in Pascal.

Build a combined test program (test_eval.pas) with lexer + parser + evaluator inlined.

Environment: linked list of (name_offset, name_len, value_pointer, next) entries via heap-allocated records.

Values: tagged records with kind field:
  VK_INT (integer), VK_BOOL (boolean), VK_CLOSURE (param name + body AST + captured env), VK_UNIT.

Evaluator (eval function): recursive AST walker that:
  - EK_INT/EK_BOOL: return literal value
  - EK_VAR: look up in environment by name
  - EK_BINOP: evaluate both sides, apply operator
  - EK_UNARY: evaluate operand, apply not
  - EK_IF: evaluate condition, branch
  - EK_LET: evaluate value, extend env, evaluate body
  - EK_LET (rec): create closure that references itself in env
  - EK_FUN: create closure capturing current env
  - EK_APP: evaluate func and arg, apply (extend closure env with arg)

Built-in: print_int recognized as a special variable that prints its argument.

Test with:
  42                              -> 42
  2 + 3 * 4                      -> 14
  let x = 41 + 1 in x            -> 42
  if 1 = 1 then 42 else 0        -> 42
  let f = fun x -> x + 1 in f 41 -> 42
  let x = 41 + 1 in print_int x  -> 42 (printed output)

Create reg-rs baselines for each test.