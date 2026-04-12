# Design Document: COR24 OCaml Interpreter

## Design Decisions

### 1. Implementation Language: Pascal on P-code VM

**Decision**: Implement the OCaml interpreter in Pascal, targeting the
P-code VM, rather than in C, Rust, or PL/SW.

**Rationale** (from research):
- Pascal's records and structured types fit AST-heavy compiler work
- Recursive descent parsing is natural in Pascal
- Tree-walk interpretation maps cleanly to Pascal's control flow
- Better maintainability and debuggability than PL/SW
- PL/SW is better suited for runtime tuning later, not front-end work

**Trade-offs**:
- Performance may be slower than a direct PL/SW implementation
- VM overhead adds a layer
- Heap allocation and dynamic data structures need care in Pascal

### 2. Tree-Walk Interpreter (Not Bytecode)

**Decision**: Start with a tree-walk interpreter, not a bytecode
compiler or VM.

**Rationale**:
- Fastest path to a working implementation
- Easiest to debug language semantics
- Ideal for proving the language subset before optimizing
- Migration to bytecode is straightforward once semantics are stable

### 3. Integer-Only Subset

**Decision**: Support only integers (no floats, no strings beyond
literals for output) in the initial implementation.

**Rationale**:
- COR24 is integer-oriented hardware
- Reduces complexity of value representation
- Sufficient for meaningful programs (factorial, fibonacci, LED control)
- Strings can be added later as needed

### 4. No Type Inference Initially

**Decision**: Defer Hindley-Milner type inference to a later phase.
The initial interpreter uses dynamic type checking.

**Rationale**:
- Type inference is a large implementation effort
- Dynamic checking is sufficient for a working interpreter
- Integer-only subset makes type errors rare
- Type inference can be layered on top without changing the evaluator

### 5. Built-in Primitives (Not FFI)

**Decision**: I/O operations are hardcoded built-in primitives in the
evaluator, not external declarations.

**Rationale**:
- Simplest possible implementation
- No need for external declaration parsing or linking
- `print_int` is the only I/O needed for the spike
- `external` declarations added in a later phase

## Grammar (Phase 0 Subset)

```
program     ::= expr

expr        ::= let_expr
              | if_expr
              | fun_expr
              | logic_expr

let_expr    ::= 'let' IDENT '=' expr 'in' expr

if_expr     ::= 'if' expr 'then' expr 'else' expr

fun_expr    ::= 'fun' IDENT '->' expr

logic_expr  ::= compare (('&&' | '||') compare)*

compare     ::= arith (('=' | '<>' | '<' | '>' | '<=' | '>=') arith)*

arith       ::= term (('+' | '-') term)*

term        ::= unary (('*' | '/' | 'mod') unary)*

unary       ::= 'not' unary
              | app

app         ::= atom+

atom        ::= INT_LITERAL
              | 'true' | 'false'
              | '(' expr ')'
              | '(' ')'
              | IDENT

IDENT       ::= [a-z_][a-zA-Z0-9_']*
INT_LITERAL ::= [0-9]+
```

## Token Set

```
(* Literals *)
INT_LITERAL

(* Identifiers and keywords *)
IDENT
LET, IN, IF, THEN, ELSE, FUN, TRUE, FALSE, NOT, MOD

(* Operators *)
PLUS, MINUS, STAR, SLASH
EQ, NEQ, LT, GT, LE, GE
AND_AND, OR_OR
ARROW        (* -> *)

(* Delimiters *)
LPAREN, RPAREN
EQUAL        (* = in let binding context *)

(* Special *)
EOF
```

## Value Representation in Pascal

```pascal
type
  ValueKind = (VK_INT, VK_BOOL, VK_CLOSURE, VK_UNIT);

  PValue = ^Value;
  PEnv = ^EnvEntry;

  Value = record
    case kind: ValueKind of
      VK_INT:     (int_val: integer);
      VK_BOOL:    (bool_val: boolean);
      VK_CLOSURE: (param: string; body: PExpr; env: PEnv);
      VK_UNIT:    ();
  end;

  EnvEntry = record
    name: string;
    val: PValue;
    next: PEnv;
  end;
```

## AST Representation in Pascal

```pascal
type
  ExprKind = (EK_INT, EK_BOOL, EK_VAR, EK_BINOP, EK_UNARY,
              EK_IF, EK_LET, EK_FUN, EK_APP);

  BinOpKind = (OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD,
               OP_EQ, OP_NEQ, OP_LT, OP_GT, OP_LE, OP_GE,
               OP_AND, OP_OR);

  PExpr = ^Expr;

  Expr = record
    case kind: ExprKind of
      EK_INT:   (int_val: integer);
      EK_BOOL:  (bool_val: boolean);
      EK_VAR:   (var_name: string);
      EK_BINOP: (op: BinOpKind; left, right: PExpr);
      EK_UNARY: (unary_op: ...; operand: PExpr);
      EK_IF:    (cond, then_br, else_br: PExpr);
      EK_LET:   (let_name: string; let_val, let_body: PExpr);
      EK_FUN:   (param: string; fun_body: PExpr);
      EK_APP:   (func, arg: PExpr);
  end;
```

Note: Exact Pascal syntax depends on the capabilities of the vendored
Pascal compiler (string handling, heap allocation, variant records).
These designs may need adaptation.

## Error Handling

For the spike, errors are simple and fatal:
- Lexer errors: "unexpected character at position N"
- Parser errors: "expected X, got Y"
- Runtime errors: "unbound variable X", "type error: expected int"
- Division by zero

No error recovery. The interpreter prints the error and halts.

## I/O Design

### Spike: `print_int`

The evaluator recognizes `print_int` as a built-in identifier.
When applied to an integer value, it outputs the decimal
representation to the UART (or stdout in emulator).

```ocaml
let x = 6 * 7 in print_int x
(* Output: 42 *)
```

### Future: Board and UART Primitives

Later phases add idiomatic OCaml-style primitives:

```ocaml
(* Built-in functions *)
switch : unit -> bool
set_led : bool -> unit
putc : char -> unit
getc : unit -> char option
```

## Directory Structure

```
sw-cor24-ocaml/
  CLAUDE.md
  README.md
  LICENSE
  COPYRIGHT
  docs/
    prd.md
    architecture.md
    design.md
    plan.md
    research.txt
    process.md
    tools.md
    ai_agent_instructions.md
  src/
    oc_main.pas
    oc_lex.pas
    oc_parse.pas
    oc_ast.pas
    oc_eval.pas
    oc_env.pas
    oc_value.pas
    oc_prim.pas
  tests/
    *.ml              # OCaml test programs
  work/
    reg-rs/           # Regression test specs and baselines
  vendor/
    active.env
    .gitignore
    sw-pasc24/        # Pascal compiler
    sw-asx24/         # Assembler
    sw-em24/          # Emulator
    sw-pcvm24/        # P-code VM
  scripts/
    vendor-fetch.sh
    build.sh
    test.sh
  .agentrail/
```
