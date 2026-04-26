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
- **Lists**: `[]`, `[1; 2; 3]`, cons `1 :: xs`, pretty-printed
- **Pairs**: `(a, b)` tuples, pretty-printed
- **Options**: `None`, `Some x`
- **Char literals**: `'a'`, `'\n'`, `'\\'`, `'\''`, represented as integer
  character codes on this target
- **Pattern matching**: `match e with p1 -> e1 | p2 -> e2 | ...`
  with patterns for ints, bools, wildcards, variables, lists,
  pairs, and options; source files may put each `| PAT -> EXPR` arm
  on its own physical line
- **Qualified names**: `List.length`, `List.rev` (dotted identifiers)
- **Multi-file modules**: pass several `.ml` files to `run-ocaml.sh`; each
  file becomes an implicit module addressed as `Module.name`

## Built-in Primitives

**Output**
- `print_int : int -> unit` -- print integer to UART
- `putc : int -> unit` -- print character (by ordinal)

**Board I/O**
- `set_led : bool -> unit`, `led_on`, `led_off` -- COR24 LED
- `switch : unit -> bool` -- read COR24 switch

**Lists and pairs**
- `nil` -- empty list value
- `hd`, `tl`, `is_empty` -- list operations
- `fst`, `snd` -- pair accessors
- `List.length`, `List.rev`, `List.hd`, `List.tl`, `List.is_empty`

**Chars**
- `Char.code : char -> int` -- identity conversion in the integer target model
- `Char.chr : int -> char` -- validates 0..255 and returns the integer code

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
just demo-fact     # factorial
just demo-led      # LED toggle demo
just demo-lists    # lists, pairs, sum/length/map
just demo-modules  # multi-file Math/Main module demo
just demo-modules-game # multi-file Game_state/Game_main demo
just demo-match    # pattern matching (idiomatic map/filter/safe_div)
```

### Canonical OCaml Demos

```ocaml
(* Factorial *)
let rec fact = fun n -> if n = 0 then 1 else n * fact (n - 1) in fact 5
(* 120 *)

(* Sum of a list *)
let rec sum = fun l -> if is_empty l then 0 else hd l + sum (tl l) in sum [1;2;3;4;5]
(* 15 *)

(* Map doubling *)
let rec map = fun f l -> if is_empty l then [] else (f (hd l)) :: (map f (tl l)) in map (fun x -> x * 2) [1;2;3]
(* [2; 4; 6] *)

(* Pairs *)
let p = (3, 4) in fst p * fst p + snd p * snd p
(* 25 *)

(* Qualified names *)
List.rev [1; 2; 3; 4; 5]
(* [5; 4; 3; 2; 1] *)

(* Pattern matching -- idiomatic OCaml *)
let rec map = fun f l -> match l with [] -> [] | h :: t -> f h :: map f t in map (fun x -> x * 2) [1;2;3]
(* [2; 4; 6] *)

let safe_div = fun x y -> if y = 0 then None else Some (x / y) in safe_div 10 3
(* Some 3 *)

match Some 7 with None -> 0 | Some n -> n + 1
(* 8 *)
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

Phase 0 (core), Phase 1 (I/O), Phase 2 (lists + pairs), and
Phase 3 (pattern matching + option) complete. 34 reg-rs tests
passing. The canonical OCaml one-liner runs correctly:

```ocaml
let rec map = fun f l -> match l with [] -> [] | h :: t -> f h :: map f t in map (fun x -> x * 2) [1;2;3]
(* [2; 4; 6] *)
```

## Documentation

- `docs/prd.md` -- Product requirements
- `docs/architecture.md` -- System architecture and runtime stack
- `docs/design.md` -- Grammar, AST, and value representations
- `docs/plan.md` -- Implementation plan
- `docs/module-system.md` -- Multi-file module MVP
- `docs/research.txt` -- Research notes on OCaml implementation strategy

## License

MIT License. See `LICENSE` for details.
