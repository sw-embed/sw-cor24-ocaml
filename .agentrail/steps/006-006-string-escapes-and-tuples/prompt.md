Implement GitHub issue #4: string escapes and arbitrary tuple arity.

Issue URL: https://github.com/sw-embed/sw-cor24-ocaml/issues/4

Target string behavior:

```ocaml
let s = "line1\nline2" in print_endline s
```

Recognize at least `\n`, `\t`, `\\`, and `\"` inside string literals.

Target tuple behavior:

```ocaml
let t = (1, 42, "hello") in
match t with
| (0, _, s) -> print_endline ("IDENT " ^ s)
| (1, n, _) -> print_endline ("INT " ^ string_of_int n)
| (_, _, _) -> print_endline "OTHER"
```

Work plan:

1. For string escapes, start in `src/oc_lex.pas`. Preserve existing raw string
   behavior except for recognized escape sequences, and define behavior for
   unknown escapes deliberately.
2. Add lexer/parser/eval tests for newline, tab, backslash, quote, and strings
   printed via `print_endline`.
3. For tuples, audit the current pair representation in AST, value, pattern
   matching, `fst`, `snd`, and destructuring tests.
4. Choose a representation for 3+ tuples:
   either a true variable-arity tuple value or parser desugaring into nested
   pairs. Prefer the option that keeps pattern matching and pretty-printing
   coherent.
5. Add tuple literal and pattern coverage for arity 3 and 4, including `_`
   wildcards and mixed payload types.
6. Run lexer/parser/eval focused tests and the standard repo test gate.

Out of scope:

- Full OCaml string escaping beyond the requested common escapes.
- Records or object syntax.
- Tuple labels or type checking.
