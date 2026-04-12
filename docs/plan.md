# Plan: Initial Spike - COR24 OCaml Interpreter

## Objective

Demonstrate a working OCaml interpreter on COR24 that can parse and
evaluate a simple expression and produce visible output.

**Target demo**: `let x = 41 + 1 in print_int x` outputs `42`

## Saga: initial-spike

### Step 1: Project Scaffolding and Vendor Setup

Set up the project directory structure, vendoring skeleton, and build
infrastructure.

- Create `src/`, `tests/`, `scripts/`, `vendor/` directories
- Set up `vendor/active.env` and `version.json` manifests
- Create `scripts/vendor-fetch.sh` (adapted from sw-cor24-plsw)
- Create initial `justfile` or `build.sh`
- Verify vendored tools can be fetched and run
- Set up `work/reg-rs/` for regression testing

### Step 2: Lexer

Implement the tokenizer in Pascal.

- Create `src/oc_lex.pas`
- Tokenize: integer literals, identifiers, keywords, operators, delimiters
- Handle whitespace and comments (`(* ... *)`)
- Test with simple inputs via reg-rs

### Step 3: AST and Parser

Implement the AST types and recursive descent parser.

- Create `src/oc_ast.pas` with AST node definitions
- Create `src/oc_parse.pas` with recursive descent parser
- Parse the Phase 0 grammar subset
- Test parsing of expressions, let bindings, if/then/else, functions

### Step 4: Evaluator and Environment

Implement the tree-walk evaluator and environment model.

- Create `src/oc_value.pas` with value type definitions
- Create `src/oc_env.pas` with environment (linked list of bindings)
- Create `src/oc_eval.pas` with recursive AST evaluator
- Create `src/oc_prim.pas` with `print_int` built-in
- Test evaluation of arithmetic, let bindings, conditionals, functions

### Step 5: Main Entry Point and Integration

Wire everything together into a complete interpreter.

- Create `src/oc_main.pas` entry point
- Read OCaml source from input (file or embedded)
- Lex -> Parse -> Eval pipeline
- Error reporting (position + message)

### Step 6: Build Pipeline and Demo

Build the interpreter, package with P-code VM, and run demo on
emulator.

- Compile Pascal sources to p-code via vendored compiler
- Package interpreter p-code with P-code VM
- Build COR24 binary via vendored assembler
- Run demo program on vendored emulator
- Verify output: `42` from `let x = 41 + 1 in print_int x`
- Set up reg-rs baseline tests for the demo

## Open Questions

- What are the exact capabilities and limitations of the vendored
  Pascal compiler? (string handling, heap allocation, variant records)
- Is there a linker step needed to combine p-code modules?
- How does the P-code VM handle I/O (stdout mapping)?

## Dependencies on Other Projects

| Project | What we need | Vendored as |
|---|---|---|
| sw-cor24-plsw (or upstream Pascal) | Pascal compiler | sw-pasc24 |
| P-code VM | Runtime for Pascal programs | sw-pcvm24 |
| sw-asx24 | COR24 cross-assembler | sw-asx24 |
| sw-em24 | COR24 emulator for testing | sw-em24 |

## Risk Mitigation

- **Pascal compiler limitations**: If the vendored Pascal compiler
  can't handle variant records or heap allocation as designed, fall
  back to simpler tagged-union representations or consider PL/SW for
  the data structures layer.
- **P-code VM I/O**: If stdout mapping is unclear, start with LED
  output as the simplest visible demo (light LED = success).
- **Build pipeline complexity**: Get a trivial "hello" Pascal program
  through the full pipeline first before building the interpreter.
