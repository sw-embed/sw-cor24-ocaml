Implement GitHub issue #2: user-defined variant types / algebraic data types.

Issue URL: https://github.com/sw-embed/sw-cor24-ocaml/issues/2

Target examples:

```ocaml
type t = A | B
let _ = match A with A -> print_endline "A" | B -> print_endline "B"
```

```ocaml
type token =
  | TInt of int
  | TIdent of string
  | TLArrow
  | TEOF

let dump tok = match tok with
  | TInt n -> string_of_int n
  | TIdent s -> s
  | TLArrow -> "<-"
  | TEOF -> "EOF"
```

Work plan:

1. Audit existing built-in constructor behavior for `Some`, `None`, list
   constructors, named ADT tests, and `tests/demo_adventure.ml`.
2. Decide the smallest runtime representation that supports nullary
   constructors and single/multiple payload constructors without requiring full
   static type checking.
3. Extend lex/parse for `type name = ...` declarations and constructor
   payload syntax, preferably as declarations that update constructor metadata
   for later expressions.
4. Extend pattern matching so user constructors bind payload variables
   consistently with existing `Some n` and list patterns.
5. Add regression tests for nullary variants, payload variants, token-style
   matching, and multiple type declarations in one file.
6. Run focused parser/eval tests plus the standard repo test gate.

Dependency:

- Prefer doing this after step 4, because top-level declarations make user type
  declarations much more useful and reduce one-giant-expression pressure.

Out of scope:

- Hindley-Milner type checking.
- GADTs, polymorphic variants, records, and recursive type validation beyond
  what the dynamic runtime needs.
