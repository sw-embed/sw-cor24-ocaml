# Product Requirements Document: COR24 OCaml Subset

## Overview

An integer-subset OCaml interpreter for the COR24 embedded platform,
implemented in Pascal and hosted on the P-code VM. This adds an
ML-family functional language to the COR24 language tower.

## Goals

1. Bring OCaml-style functional programming to COR24
2. Extend the COR24 language tower (C -> Pascal -> PL/SW -> BASIC -> SNOBOL4 -> Fortran -> **OCaml**)
3. Provide an educational, tractable implementation of ML-family semantics
4. Enable idiomatic embedded I/O through built-in primitives

## Non-Goals (for initial development)

- Full OCaml compatibility
- Module system
- Full type inference / polymorphism
- Exceptions
- Objects / classes / functors
- Separate compilation
- Native code generation (OCaml compiles to p-code in a later saga)

## Language Subset (Phased)

### Phase 0: Expression Evaluator (Initial Spike)

- Integer literals
- Variables
- `let` bindings
- `if` / `then` / `else`
- Arithmetic operators: `+`, `-`, `*`, `/`, `mod`
- Comparison operators: `=`, `<>`, `<`, `>`, `<=`, `>=`
- Boolean operators: `&&`, `||`, `not`
- One-argument functions: `fun x -> ...`
- Function application
- Simplest I/O: `print_int` built-in

### Phase 1: Recursion

- `let rec`
- Recursive functions (factorial, fibonacci)

### Phase 2: Lists and Tuples

- Pairs / tuples
- Lists with `[]`, `::`, `[1;2;3]` syntax

### Phase 3: Pattern Matching

- `match ... with`
- Wildcard `_`
- Constant patterns
- Constructor patterns (for lists, option)

### Phase 4: Optional Static Typing

- Hindley-Milner type inference
- Type annotations

## Target Hardware

- COR24 embedded processor
- Switch (read-only input)
- LED (write-only output)
- Memory-mapped UART with interrupts and RTS/CTS

## I/O Primitives

Initial spike: `print_int : int -> unit`

Future phases add:
- `switch : unit -> bool`
- `set_led : bool -> unit`
- `putc : char -> unit`
- `getc : unit -> char option`

## Runtime Architecture

```
COR24 hardware
  -> native startup
    -> native p-code VM (AOT-compiled)
      -> Pascal OCaml interpreter (p-code)
        -> OCaml source program
```

## Success Criteria (Initial Spike)

Demonstrate a working OCaml interpreter on COR24 that can:
- Parse and evaluate a simple OCaml expression
- Produce visible output (print an integer, or light the LED)
- Example: `let x = 41 + 1 in print_int x` outputs `42`

## Dependencies

- Pascal compiler targeting P-code (vendored from sw-cor24-plsw or upstream)
- P-code VM (vendored)
- COR24 assembler (vendored)
- COR24 emulator (vendored, for testing)

## Testing Strategy

- reg-rs regression testing framework
- Golden-baseline tests: OCaml source input -> expected output
- Tests run via emulator on host
