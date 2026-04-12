# Architecture: COR24 OCaml Interpreter

## System Context

The OCaml interpreter is one layer in the COR24 language tower:

```
COR24 hardware
  |
  +-- C compiler (sw-cx24)
  +-- Assembler (sw-asx24)
  +-- P-code VM
  |     |
  |     +-- Pascal compiler
  |     +-- PL/SW compiler
  |     +-- BASIC interpreter
  |     +-- SNOBOL4 interpreter
  |     +-- Fortran compiler
  |     +-- **OCaml interpreter** <-- this project
  |
  +-- Emulator (sw-em24)
```

## Runtime Stack

In interpreted mode (the initial and primary target):

```
COR24 native binary
  -> startup code
    -> P-code VM (AOT-compiled to COR24 native)
      -> Pascal OCaml interpreter (compiled to p-code)
        -> OCaml source program (text or serialized AST)
```

The P-code VM is the execution engine. The OCaml interpreter is a
Pascal program that runs on the VM. The OCaml user program is data
consumed by the interpreter.

## Interpreter Architecture

The interpreter is a classic tree-walk design:

```
OCaml source text
  -> Lexer (oc_lex.pas)
    -> Token stream
      -> Parser (oc_parse.pas)
        -> AST (oc_ast.pas)
          -> Evaluator (oc_eval.pas)
            -> Values / side effects
```

### Module Breakdown

| Module | Responsibility |
|---|---|
| `oc_lex.pas` | Tokenizer: source text -> token stream |
| `oc_parse.pas` | Recursive descent parser: tokens -> AST |
| `oc_ast.pas` | AST node type definitions |
| `oc_eval.pas` | Tree-walk evaluator: AST -> values |
| `oc_env.pas` | Environment / variable bindings |
| `oc_value.pas` | Runtime value representation |
| `oc_prim.pas` | Built-in primitive functions (I/O) |
| `oc_main.pas` | Entry point, REPL or file loader |

### AST Node Types (Phase 0)

```
Expr =
  | IntLit of integer
  | BoolLit of boolean
  | Var of string
  | BinOp of op * Expr * Expr
  | UnaryOp of op * Expr
  | If of Expr * Expr * Expr
  | Let of string * Expr * Expr
  | Fun of string * Expr
  | App of Expr * Expr
```

### Value Types (Phase 0)

```
Value =
  | VInt of integer
  | VBool of boolean
  | VClosure of string * Expr * Env
  | VUnit
```

### Environment Model

Environments are linked lists of (name, value) bindings:

```
Env = nil | (name, value, parent_env)
```

Variable lookup walks the chain from innermost to outermost scope.
Closures capture the environment at the point of function definition.

## Build Pipeline

```
Pascal sources (src/*.pas)
  -> Pascal compiler (vendored)
    -> P-code image (build/ocaml_interp.pcode)

P-code VM source (vendored)
  -> AOT compiler
    -> cor24.s
      -> Assembler (vendored)
        -> COR24 binary

Package:
  P-code VM binary + interpreter p-code + OCaml source
  -> final COR24 application image
```

## Vendored Dependencies

Following the pattern from sw-cor24-plsw:

```
vendor/
  active.env                    # Active tool versions
  .gitignore                    # Ignores bin/ directories
  sw-pasc24/v<version>/         # Pascal compiler
    version.json
    bin/
  sw-asx24/v<version>/          # COR24 assembler
    version.json
    bin/
  sw-em24/v<version>/           # COR24 emulator
    version.json
    bin/
  sw-pcvm24/v<version>/         # P-code VM
    version.json
    bin/
```

## Testing Architecture

Tests use the reg-rs regression framework:

```
work/reg-rs/
  hello_int.rgt         # Test spec (TOML)
  hello_int.out         # Expected stdout baseline
  expr_arith.rgt
  expr_arith.out
  ...
```

Test execution flow:
1. Compile interpreter Pascal sources to p-code
2. Run p-code VM + interpreter + test OCaml program in emulator
3. Capture output, compare against baseline

## Future Architecture (Later Sagas)

- **Compiled mode**: OCaml source -> OCaml bytecode -> bytecode executor
- **Direct p-code mode**: OCaml source -> p-code (no interpreter at runtime)
- **Board support modules**: `Board`, `Uart`, `Mmio` modules for device I/O
- **External declarations**: `external` keyword for FFI-like primitive binding
