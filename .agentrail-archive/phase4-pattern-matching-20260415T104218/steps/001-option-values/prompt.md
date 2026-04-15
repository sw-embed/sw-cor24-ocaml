Add option type values (None/Some) as a natural fit for pattern matching demos.

Values:
- Add VK_NONE=8, VK_SOME=9 constants.
- mk_val_none(): returns a fresh VK_NONE.
- mk_val_some(x): returns VK_SOME with head := x.

Syntax (lowercase names already in use as builtins; these are new):
- 'None' parsed as built-in nullary identifier (like 'nil').
- 'Some e' parsed as application of built-in 'Some' to its argument,
  but OCaml treats Some as a constructor. Simplest for our parser:
  treat 'Some' as a built-in function, so 'Some 3' is regular function
  application.

EK_VAR recognizes 'None' -> mk_val_none, 'Some' -> closure that dispatches
to Some-constructor on application.

Pretty-printer:
- VK_NONE prints 'None'
- VK_SOME prints 'Some <value>' (use parens if needed for clarity? no, just Some 3)

Tests:
  > None              None
  > Some 42           Some 42
  > Some [1;2;3]      Some [1; 2; 3]
  > let x = Some 7 in x   Some 7