Investigate stdin/UART input support in the COR24 toolchain and add a getc : unit -> char built-in to the OCaml interpreter.

## Scope

This is a foundational step — no demo yet, just get a single character read from UART through the interpreter.

## Investigation tasks

1. Check vendor/sw-pcode for input primitives. The pvm likely has some way to read UART input (check pvm.s, or its documentation). Look for 'read', 'input', 'uart_in', 'getc', or similar.
2. Check how the interpreter currently handles output primitives (putc specifically) — grep for putc_noff in src/ocaml.pas. getc will be the mirror image.
3. Check vendor/sw-pascal for any Pascal read primitive wired through — how does the lexer's 'read(ch)' work at runtime? Does that already give us what we need?

## Implementation

Add a getc : unit -> char built-in to src/ocaml.pas:

1. Intern the name 'getc' in the name pool (mirror intern_putc).
2. Add evaluator dispatch so getc () reads one character from stdin and returns it as a char value (our char values are ints in the 0..255 range since we don't have a distinct char type — see how putc consumes its char argument).
3. If the character read is EOF or unavailable, decide on a sentinel (e.g., -1 or 0) and document it.

## Testing

Create tests/eval_getc_echo.ml:
    let c = getc () in putc c

Run it through the toolchain. Since stdin is consumed by the Pascal compiler first (compiling the source), we need to verify: does run-ocaml.sh allow stdin to reach the interpreter at runtime? If not, that's a real blocker worth flagging — the way user-facing input gets through to the interpreter may need work.

## Deliverables

- src/ocaml.pas: getc built-in added (intern + dispatch)
- tests/eval_getc_echo.ml: smoke test demonstrating one char round-trip
- Notes in docs/ on the EOF sentinel and any stdin-plumbing surprise
- justfile: a 'demo-echo' target if the round-trip works

## Scope discipline

- Do not implement read_line yet — that's step 002.
- Do not touch the text adventure — that's step 004.
- If stdin-plumbing blocks runtime input entirely, STOP, document the blocker, and complete this step with --reward -1 and --failure-mode explaining what needs to change upstream.