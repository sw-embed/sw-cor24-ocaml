Unblock and implement step 004-named-adts (it was blocked pending strings; strings landed in 015).

Add named algebraic data types (enum-style) for demos like 'type color = Red | Green | Blue'.

Scope: nullary constructors only (no 'type shape = Circle of int | Square of int' yet).

Syntax:
  type IDENT = IDENT ('|' IDENT)*

This is a top-level declaration, evaluated at REPL parse time. The REPL
would need to recognize this as a declaration (not an expression) and
update a global table of (constructor_name -> tag) mappings.

Values:
- Reuse VK_SOME/VK_NONE approach or add VK_CTOR with a tag integer.
  Simplest: VK_CTOR=11 with ival = tag (index in the declaration).
  Each declared constructor becomes a nullary builtin that evaluates
  to VK_CTOR with its tag.

Parser:
- Add TK_TYPE keyword. In parse_expr, if tok=TK_TYPE, parse type decl:
  type T = C1 | C2 | C3
  Declaration returns a unit value; side effect: registers constructors.

Constructor registry: global table constructor_names[] and constructor_tags[].
EK_VAR looks up constructors after all other built-ins.

Pattern matching:
- Add PK_CTOR with ival=tag. try_match checks v^.vk = VK_CTOR
  and v^.ival = pattern's tag.

Pretty-printer:
- VK_CTOR walks the constructor registry to find the name. Print it.

Tests (add to reg-rs):
  > type color = Red | Green | Blue
  (declaration; no visible output or 'unit')
  > Red                            Red
  > Green                          Green
  > match Red with Red -> 1 | Green -> 2 | Blue -> 3     1
  > let name = function Red -> 1 | Green -> 2 | Blue -> 3 in name Green     2

Stay within the interpreter source (src/ocaml.pas or equivalent) and add the regression tests. Do not scope-expand to constructors-with-args.