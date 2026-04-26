# Module System MVP

This project supports a small whole-program module model for building one
application from multiple `.ml` files. It is intentionally much smaller than
OCaml's full module system.

## Supported Model

Each input file is an implicit module. The module name is derived from the file
stem by capitalizing the first character:

| File | Module |
| --- | --- |
| `math.ml` | `Math` |
| `main.ml` | `Main` |
| `game_state.ml` | `Game_state` |

Run multiple files by passing them to `scripts/run-ocaml.sh` in dependency
order:

```bash
./scripts/run-ocaml.sh demos/modules/math.ml demos/modules/main.ml
```

or through the demo targets:

```bash
just demo-modules
just demo-modules-game
```

All files are compiled and evaluated together into one COR24 image. There is no
separate object format and no linker step for individual OCaml source files.

## Name Resolution

Top-level definitions inside a file are stored under their qualified module
name. For example:

```ocaml
(* math.ml *)
let add x y = x + y
let square x = x * x
```

defines:

```text
Math.add
Math.square
```

Another file must use qualified names:

```ocaml
(* main.ml *)
Math.square (Math.add 2 3)
```

Unqualified names are local to the current file/module plus built-in names.
Cross-file unqualified lookup is deliberately rejected:

```ocaml
(* main.ml *)
add 2 3      (* EVAL ERROR unless Main.add exists *)
Math.add 2 3 (* OK *)
```

Within a module, helpers can call earlier helpers without qualification:

```ocaml
(* math.ml *)
let add x y = x + y
let double x = add x x
```

After another module becomes active, `double` is still available as
`Math.double`, and its closure keeps the local `add` binding it captured.

## Driver Behavior

`scripts/run-ocaml.sh` remains backward compatible for a single input file:

```bash
./scripts/run-ocaml.sh tests/eval_int.ml
./scripts/run-ocaml.sh tests/eval_int.ml 500000000
```

For two or more `.ml` inputs, the runner injects an internal directive before
each file:

```ocaml
let __module = "Math"
```

The interpreter treats this as a reserved compile-unit marker. User programs
should not define `__module`.

The optional instruction limit is still accepted as the final argument:

```bash
./scripts/run-ocaml.sh math.ml main.ml 500000000
```

## Examples

Minimal two-file app:

```ocaml
(* demos/modules/math.ml *)
let add x y = x + y
let square x = x * x
let cube x = x * square x
```

```ocaml
(* demos/modules/main.ml *)
Math.add 20 22
Math.square 12
Math.cube 5
```

Structured demo:

```ocaml
(* demos/modules/game_state.ml *)
type room = Hall | Cave | Vault
let describe room = match room with Hall -> "hall" | Cave -> "cave" | Vault -> "vault"
let score room has_lamp = match room with Hall -> 1 | Cave -> if has_lamp then 10 else 2 | Vault -> if has_lamp then 50 else 5
```

```ocaml
(* demos/modules/game_main.ml *)
print_endline (Game_state.describe Cave)
Game_state.score Cave true
Game_state.score Vault false
```

## Deferred Features

These OCaml module features are not implemented in this MVP:

- `.mli` interface files
- `module M = struct ... end`
- `module type S = sig ... end`
- nested modules
- functors
- `open`, local open, and `include`
- module aliases
- public/private export controls
- separate compilation
- object files or module-level linking

The current implementation is a pragmatic multi-file application mechanism:
implicit file modules, qualified cross-file references, and one combined
runtime image.
