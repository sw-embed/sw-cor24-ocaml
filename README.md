# sw-cor24-ocaml

An integer-subset OCaml interpreter for the COR24 embedded platform,
implemented in Pascal and hosted on the P-code VM.

## Overview

This project adds an ML-family functional language to the COR24
language tower. The interpreter is a tree-walk design written in Pascal,
compiled to P-code, and executed on the P-code VM which itself runs as
an AOT-compiled native COR24 binary.

## Language Features

- Integer literals, arithmetic (`+`, `-`, `*`, `/`, `mod`)
- Comparisons (`=`, `<>`, `<`, `>`, `<=`, `>=`) and booleans (`&&`, `||`, `not`)
- Variables and `let` bindings, `let rec` for recursion
- Conditionals (`if`/`then`/`else`)
- First-class functions: `fun x -> body`, multi-arg `fun x y z -> body`
- Function application by juxtaposition: `f x`, `f x y`
- Semicolon sequencing: `e1; e2`
- Negative literals: `-42`
- Comments: `(* ... *)` (nestable)

## Built-in Primitives

- `print_int : int -> unit` -- print integer to UART
- `putc : int -> unit` -- print character (by ordinal)
- `set_led : bool -> unit` -- set COR24 LED state
- `led_on : unit -> unit`, `led_off : unit -> unit` -- LED helpers
- `switch : unit -> bool` -- read COR24 switch

## Quick Start

```bash
./scripts/vendor-fetch.sh    # fetch vendored toolchain
just build                    # build the interpreter
just test                     # run 27 regression tests
```

## Try It Out

```bash
just repl          # launch interactive REPL (terminal mode)
just demo-repl     # run scripted REPL session
just demo          # one-shot: print_int 42
just demo-fact     # one-shot: print_int (fact 5) -> 120
just demo-led      # LED toggle demo
```

### Interactive Session Example

```bash
$ just repl
OCaml REPL on COR24 -- type expressions, Ctrl-C to exit
Try: 42
     let x = 41 + 1 in x
     let f = fun x -> x * 2 in f 21
     let rec fact = fun n -> if n = 0 then 1 else n * fact (n - 1) in fact 5
     print_int 99
     led_on (); print_int 1
----------------------------------------
PVM OK
> 42                                          <-- you type
42                                            <-- result
> let x = 41 + 1 in x                         <-- you type
42                                            <-- result
> let rec fact = fun n -> if n = 0 then 1 else n * fact (n - 1) in fact 5
120
```

## Status

All Phase 0 + Phase 1 features working in REPL mode. 27 reg-rs tests passing.
Lists, pairs, and pattern matching planned for Phase 2 (in progress).

## Documentation

- `docs/prd.md` -- Product requirements
- `docs/architecture.md` -- System architecture and runtime stack
- `docs/design.md` -- Grammar, AST, and value representations
- `docs/plan.md` -- Implementation plan
- `docs/research.txt` -- Research notes on OCaml implementation strategy

## License

MIT License. See `LICENSE` for details.
