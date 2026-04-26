Implement GitHub issue #3: top-level `let` bindings without `in EXPR`.

Issue URL: https://github.com/sw-embed/sw-cor24-ocaml/issues/3

Target behavior:

```ocaml
let greet = fun name -> print_endline ("hello, " ^ name)
let _ = greet "world"
let _ = greet "tuplet"
```

The binding should persist across the rest of the file, equivalent to chaining
the file into one expression:

```ocaml
let greet = ... in
let _ = greet "world" in
let _ = greet "tuplet" in
()
```

Work plan:

1. Determine how `src/ocaml.pas` currently reads and evaluates each source
   line/expression, and whether the right model is a persistent global env or a
   parser-level desugaring of the whole file into nested lets.
2. Preserve existing `let ... in ...`, `let rec ... in ...`, function
   shorthand, pattern let, and REPL behavior.
3. Add parsing/evaluation support for declarations:
   `let name = expr`, `let rec name = expr`, `let f x y = expr`, and
   `let () = expr` where supported by existing patterns.
4. Make top-level declarations visible to subsequent expressions in the same
   file.
5. Add focused tests that cover helper reuse, recursive helper reuse, function
   shorthand, and multiple print expressions.
6. Run parser/eval/reg-rs gates used by the repo.

Out of scope:

- Full OCaml module semantics.
- Mutual `let rec ... and ...`.
- Type inference.
